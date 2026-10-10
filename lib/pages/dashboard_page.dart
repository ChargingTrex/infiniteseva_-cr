import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/progress.dart';

// ───────────────────────── model ─────────────────────────

class Recitation {
  final int id;
  final DateTime date;
  final int quantity;
  final DateTime? start;
  final DateTime? end;
  final int duration;
  final String type;
  final int? teamSize;
  final bool hasPhoto;
  final double? lat;
  final double? lng;
  final String? address;

  Recitation({
    required this.id,
    required this.date,
    required this.quantity,
    this.start,
    this.end,
    required this.duration,
    required this.type,
    this.teamSize,
    required this.hasPhoto,
    this.lat,
    this.lng,
    this.address,
  });

  factory Recitation.fromJson(Map<String, dynamic> j) {
    DateTime? dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    double? dbl(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return Recitation(
      id: int.parse(j['id'].toString()),
      date: dt(j['date']) ?? DateTime.now(),
      quantity: int.tryParse((j['quantity'] ?? 1).toString()) ?? 1,
      start: dt(j['startTime']),
      end: dt(j['endTime']),
      duration: int.tryParse((j['durationSeconds'] ?? 0).toString()) ?? 0,
      type: (j['type'] ?? 'INDIVIDUAL').toString(),
      teamSize: int.tryParse((j['teamSize'] ?? '').toString()),
      hasPhoto: j['hasPhoto'] == true,
      lat: dbl(j['latitude']),
      lng: dbl(j['longitude']),
      address: (j['locationAddress'] ?? '').toString().isEmpty
          ? null
          : j['locationAddress'].toString(),
    );
  }

  bool get isTeam => type == 'TEAM';
  String? get mapLink => (lat != null && lng != null) ? mapsUrl(lat!, lng!) : null;

  String locationText([int digits = 4]) =>
      address ??
      ((lat != null && lng != null)
          ? '${lat!.toStringAsFixed(digits)}, ${lng!.toStringAsFixed(digits)}'
          : '');
}

// ───────────────────────── helpers ─────────────────────────

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _fmtDuration(int secs, String Function(String) t) {
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  final s = secs % 60;
  if (h > 0) return '$h${t('dashboard.h')} $m${t('dashboard.m')}';
  if (m > 0) return '$m${t('dashboard.m')} $s${t('dashboard.s')}';
  return '$s${t('dashboard.s')}';
}

String _fmtDurationLong(int secs, String Function(String) t) {
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  if (h > 0) return '$h${t('dashboard.h')} $m${t('dashboard.m')}';
  return '$m${t('dashboard.m')}';
}

String _friendlyDate(DateTime d, AppState app) {
  final now = DateTime.now();
  if (_dayKey(d) == _dayKey(now)) return app.t('dashboard.today');
  if (_dayKey(d) == _dayKey(now.subtract(const Duration(days: 1)))) {
    return app.t('dashboard.yesterday');
  }
  return DateFormat('dd MMM yyyy', app.isTamil ? 'ta' : 'en_IN').format(d);
}

String _time(DateTime d) => DateFormat('hh:mm a').format(d);

class _WeekDay {
  final String key;
  final String label;
  final int count;
  final bool isToday;
  _WeekDay(this.key, this.label, this.count, this.isToday);
}

class _Stats {
  final int totalSeconds;
  final int sessionsWithTime;
  final int avgSeconds;
  final List<_WeekDay> week;
  final int streak;
  _Stats(this.totalSeconds, this.sessionsWithTime, this.avgSeconds, this.week, this.streak);
}

_Stats _computeStats(List<Recitation> history, String locale) {
  final totalSeconds = history.fold<int>(0, (s, h) => s + h.duration);
  final sessions = history.where((h) => h.duration > 0).length;
  final avg = sessions > 0 ? (totalSeconds / sessions).round() : 0;

  final perDay = <String, int>{};
  for (final h in history) {
    final k = _dayKey(h.date);
    perDay[k] = (perDay[k] ?? 0) + (h.quantity > 0 ? h.quantity : 1);
  }

  final week = <_WeekDay>[];
  final now = DateTime.now();
  for (var i = 6; i >= 0; i--) {
    final d = now.subtract(Duration(days: i));
    week.add(_WeekDay(_dayKey(d), DateFormat('EEEEE', locale).format(d),
        perDay[_dayKey(d)] ?? 0, i == 0));
  }

  var streak = 0;
  var cursor = now;
  if (!perDay.containsKey(_dayKey(cursor))) cursor = cursor.subtract(const Duration(days: 1));
  while (perDay.containsKey(_dayKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return _Stats(totalSeconds, sessions, avg, week, streak);
}

const _pageSize = 12;
const _swipeLimit = 12;

// ───────────────────────── page ─────────────────────────

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _dashboard;
  List<Recitation> _history = [];
  bool _loading = true;
  String _error = '';
  String _view = 'swipe'; // swipe | table | grid
  int _visible = _pageSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppState.instance.user == null) {
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        _load();
      }
    });
  }

  Future<void> _load() async {
    final user = AppState.instance.user;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await Future.wait([
        Api.instance.myDashboard(user.id),
        Api.instance.myHistory(user.id),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = res[0] as Map<String, dynamic>;
        _history = (res[1] as List<Map<String, dynamic>>).map(Recitation.fromJson).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppState.instance.t('dashboard.loadError');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = app.t;
    final user = app.user;

    final stats = _computeStats(_history, app.isTamil ? 'ta' : 'en_IN');
    final mine = ((_dashboard?['batch1']?['completed'] ?? 0) as num).toInt();
    final globalTotal = ((_dashboard?['campaign']?['total'] ?? 0) as num).toInt();
    final totalIsValid = globalTotal > 0 && globalTotal >= mine;
    final share = totalIsValid ? mine / globalTotal * 100 : 0.0;
    final ringPercent =
        mine > 0 ? (totalIsValid ? (share < 4 ? 4.0 : share) : 100.0) : 0.0;

    return PageShell(
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: C.maroon,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text('${t('dashboard.namaste')} 🙏',
                      style: body(14, color: C.neutral500)),
                  Text(user?.name.isNotEmpty == true ? user!.name : (user?.mobile ?? ''),
                      style: body(24, weight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  if (_loading) _skeleton(),
                  if (_error.isNotEmpty && !_loading) _errorCard(t),
                  if (_dashboard != null && !_loading) ...[
                    _heroCard(app, mine, globalTotal, totalIsValid, share, ringPercent, stats),
                    const SizedBox(height: 16),
                    if (stats.totalSeconds > 0) ...[
                      Row(
                        children: [
                          _StatTile(
                              icon: '⏳',
                              value: _fmtDurationLong(stats.totalSeconds, t),
                              label: t('dashboard.totalTime'),
                              color: C.blue),
                          const SizedBox(width: 10),
                          _StatTile(
                              icon: '⚡',
                              value: _fmtDurationLong(stats.avgSeconds, t),
                              label: t('dashboard.perSession'),
                              color: C.maroon),
                          const SizedBox(width: 10),
                          _StatTile(
                              icon: '📿',
                              value: '${stats.sessionsWithTime}',
                              label: t('dashboard.timedSessions'),
                              color: C.orange),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_history.isNotEmpty) ...[
                      _weekStrip(stats, t),
                      const SizedBox(height: 20),
                    ],
                    _historySection(app),
                  ],
                ],
              ),
            ),
          ),
          if (_dashboard != null && !_loading)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4)),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: PrimaryButton(
                    label: t('dashboard.completedParayanam'),
                    onPressed: () => Navigator.of(context).pushNamed('/participate'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _skeleton() => const Column(
        children: [
          Skeleton(height: 200, radius: 24),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Skeleton(height: 100)),
              SizedBox(width: 10),
              Expanded(child: Skeleton(height: 100)),
              SizedBox(width: 10),
              Expanded(child: Skeleton(height: 100)),
            ],
          ),
          SizedBox(height: 16),
          Skeleton(height: 220),
        ],
      );

  Widget _errorCard(String Function(String) t) => GoldCard(
        child: Column(
          children: [
            const Text('🕉️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            Text(_error, textAlign: TextAlign.center, style: body(14, color: C.neutral700)),
            const SizedBox(height: 16),
            PrimaryButton(label: t('dashboard.tryAgain'), onPressed: _load),
          ],
        ),
      );

  Widget _heroCard(AppState app, int mine, int globalTotal, bool totalIsValid, double share,
      double ringPercent, _Stats stats) {
    final t = app.t;
    final shareText = mine == 0
        ? t('dashboard.firstRecitation')
        : totalIsValid
            ? t('dashboard.shareText').replaceAll(
                '{pct}', share < 0.1 ? t('dashboard.lessThan01') : share.toStringAsFixed(1))
            : t('dashboard.everyRecitation');

    return Container(
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.maroon, Color(0xFF4A0F1C)],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                percent: ringPercent,
                size: 140,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      child: Text(fmt(mine),
                          style: body(34, color: Colors.white, weight: FontWeight.w800)),
                    ),
                    Text(t('dashboard.myParayanams'),
                        textAlign: TextAlign.center,
                        style: body(10.5, color: Colors.white.withOpacity(0.7))),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('dashboard.globalTotal'),
                        style: body(12, color: Colors.white.withOpacity(0.7))),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(totalIsValid ? fmt(globalTotal) : '—',
                          style: body(26, color: const Color(0xFFF4C95D), weight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 10),
                    Text(shareText,
                        style: body(12, color: Colors.white.withOpacity(0.8), height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          if (stats.streak > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '🔥 ${stats.streak} ${stats.streak == 1 ? t('dashboard.dayStreak') : t('dashboard.daysStreak')}',
                style: body(12, color: Colors.white, weight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weekStrip(_Stats stats, String Function(String) t) {
    final active = stats.week.where((d) => d.count > 0).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('dashboard.thisWeek'), style: body(14, weight: FontWeight.w700)),
              Text('$active ${t('dashboard.of7Days')}',
                  style: body(12, color: C.neutral500)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in stats.week)
                Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d.count > 0 ? C.goldDark : const Color(0xFFF5F5F5),
                        border: d.isToday
                            ? Border.all(color: C.goldDark.withOpacity(0.6), width: 2)
                            : null,
                      ),
                      child: Text(d.count > 0 ? '${d.count}' : '·',
                          style: body(12,
                              color: d.count > 0 ? Colors.white : const Color(0xFFD4D4D4),
                              weight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    Text(d.label,
                        style: body(11,
                            color: d.isToday ? const Color(0xFF262626) : const Color(0xFFA3A3A3),
                            weight: d.isToday ? FontWeight.w700 : FontWeight.w400)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5F5F5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      );

  Widget _historySection(AppState app) {
    final t = app.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('dashboard.recentRecitations'),
                      style: body(16, weight: FontWeight.w700)),
                  if (_history.isNotEmpty)
                    Text('${_history.length} ${t('dashboard.total')}',
                        style: body(12, color: C.neutral500)),
                ],
              ),
            ),
            if (_history.isNotEmpty) _viewToggle(t),
          ],
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4D4D4)),
            ),
            child: Column(
              children: [
                const Text('🙏', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(t('dashboard.noRecitationsYet'),
                    style: body(15, color: C.neutral700, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(t('dashboard.completeFirst'),
                    textAlign: TextAlign.center, style: body(13, color: C.neutral500)),
              ],
            ),
          )
        else if (_view == 'swipe')
          _swipeView(app)
        else if (_view == 'table')
          _tableView(app)
        else
          _gridView(app),
      ],
    );
  }

  Widget _viewToggle(String Function(String) t) {
    final options = [
      ('swipe', t('dashboard.swipe'), '⇆'),
      ('table', t('dashboard.table'), '☰'),
      ('grid', t('dashboard.grid'), '▦'),
    ];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => setState(() => _view = o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _view == o.$1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _view == o.$1
                      ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 3)]
                      : null,
                ),
                child: Text('${o.$3} ${o.$2}',
                    style: body(12,
                        color: _view == o.$1 ? const Color(0xFF171717) : C.neutral500,
                        weight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  // ───────── swipe ─────────
  Widget _swipeView(AppState app) {
    final t = app.t;
    final rows = _history.take(_swipeLimit).toList();
    final cardWidth = MediaQuery.of(context).size.width * 0.72;
    return SizedBox(
      height: 250,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: rows.length + (_history.length > rows.length ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          if (i >= rows.length) {
            return GestureDetector(
              onTap: () => setState(() => _view = 'table'),
              child: Container(
                width: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4D4D4)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('☰', style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text('${t('dashboard.viewAll')} ${_history.length}',
                        style: body(14, color: C.neutral700, weight: FontWeight.w600)),
                    Text(t('dashboard.inTable'), style: body(12, color: C.neutral500)),
                  ],
                ),
              ),
            );
          }
          final h = rows[i];
          return Container(
            width: cardWidth.clamp(240.0, 320.0),
            clipBehavior: Clip.antiAlias,
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (h.hasPhoto)
                  _photo(h, height: 100)
                else
                  Container(height: 8, color: h.isTeam ? C.goldDark : C.blue),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_friendlyDate(h.date, app),
                                      style: body(14, color: const Color(0xFF262626), weight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  _typeBadge(h, t),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: C.goldDark.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('+${h.quantity}',
                                  style: body(20, color: C.goldDark, weight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        if (h.start != null && h.end != null) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFF5F5F5)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text('🕐 ${_time(h.start!)} → ${_time(h.end!)}',
                                    style: body(11.5, color: C.neutral500)),
                              ),
                              Text('⏱ ${_fmtDuration(h.duration, t)}',
                                  style: body(11.5, color: C.neutral700, weight: FontWeight.w600)),
                            ],
                          ),
                        ],
                        if (h.mapLink != null || h.address != null) ...[
                          const SizedBox(height: 8),
                          _locationLink(h, 3),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ───────── table / list ─────────
  Widget _tableView(AppState app) {
    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < _history.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF5F5F5)),
            _HistoryRow(h: _history[i], app: app, photoBuilder: _photo, locationBuilder: _locationLink),
          ],
        ],
      ),
    );
  }

  // ───────── grid ─────────
  Widget _gridView(AppState app) {
    final t = app.t;
    final rows = _history.take(_visible).toList();
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, i) {
            final h = rows[i];
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (h.hasPhoto) _photo(h, height: 80),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Text(_friendlyDate(h.date, app),
                                    style: body(13, color: const Color(0xFF262626), weight: FontWeight.w700)),
                              ),
                              Text('+${h.quantity}',
                                  style: body(15, color: C.goldDark, weight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _typeBadge(h, t),
                          if (h.duration > 0) ...[
                            const SizedBox(height: 6),
                            Text('⏱ ${_fmtDuration(h.duration, t)}',
                                style: body(11.5, color: C.neutral500)),
                          ],
                          if (h.start != null && h.end != null)
                            Text('${_time(h.start!)} – ${_time(h.end!)}',
                                style: body(10.5, color: const Color(0xFFA3A3A3))),
                          if (h.mapLink != null || h.address != null) ...[
                            const Spacer(),
                            _locationLink(h, 3, small: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_visible < _history.length) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _visible += _pageSize),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: C.neutral700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: C.neutral200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                  '${t('dashboard.showMore')} (${_history.length - _visible} ${t('dashboard.left')})',
                  style: body(13.5, weight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }

  // ───────── shared bits ─────────
  Widget _photo(Recitation h, {double height = 100}) => Image.network(
        Api.instance.photoUrl(h.id),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );

  Widget _locationLink(Recitation h, int digits, {bool small = false}) {
    return GestureDetector(
      onTap: h.mapLink != null ? () => openUrl(h.mapLink!) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📍', style: TextStyle(fontSize: small ? 10 : 12)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(h.locationText(digits),
                maxLines: small ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: body(small ? 10.5 : 12, color: C.blue)),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(Recitation h, String Function(String) t) => _TypeBadge(isTeam: h.isTeam, t: t);
}

// ───────────────────────── small widgets ─────────────────────────

class _TypeBadge extends StatelessWidget {
  final bool isTeam;
  final String Function(String) t;
  const _TypeBadge({required this.isTeam, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isTeam ? C.goldDark : C.blue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isTeam ? '👥 ${t('dashboard.team')}' : '🧘 ${t('dashboard.solo')}',
        style: body(11,
            color: isTeam ? const Color(0xFF8A6508) : C.blue, weight: FontWeight.w600),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  const _StatTile({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF5F5F5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.1)),
              child: Text(icon, style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: body(20, color: color, weight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: body(11, color: C.neutral700, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final Recitation h;
  final AppState app;
  final Widget Function(Recitation, {double height}) photoBuilder;
  final Widget Function(Recitation, int, {bool small}) locationBuilder;

  const _HistoryRow({
    required this.h,
    required this.app,
    required this.photoBuilder,
    required this.locationBuilder,
  });

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.h;
    final app = widget.app;
    final t = app.t;
    final hasExtras = (h.start != null && h.end != null) ||
        h.hasPhoto ||
        h.mapLink != null ||
        h.address != null;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            color: _open ? C.goldDark.withOpacity(0.05) : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Text('▶', style: TextStyle(fontSize: 10, color: Color(0xFFA3A3A3))),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: Text(_friendlyDate(h.date, app),
                      style: body(13.5, color: const Color(0xFF262626), weight: FontWeight.w600)),
                ),
                _TypeBadge(isTeam: h.isTeam, t: t),
                const SizedBox(width: 10),
                Text('+${h.quantity}',
                    style: body(14, color: C.goldDark, weight: FontWeight.w800)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  child: Text(h.duration > 0 ? _fmtDuration(h.duration, t) : '—',
                      textAlign: TextAlign.right,
                      style: body(12, color: C.neutral500)),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Container(
            width: double.infinity,
            color: C.goldDark.withOpacity(0.05),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: !hasExtras
                ? Text(t('dashboard.noExtraDetails'),
                    style: body(12, color: const Color(0xFFA3A3A3)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (h.start != null && h.end != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('🕐 ${_time(h.start!)} → ${_time(h.end!)}',
                                  style: body(12, color: C.neutral700)),
                              Text('⏱ ${_fmtDuration(h.duration, t)}',
                                  style: body(12, color: C.neutral700, weight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      if (h.hasPhoto)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: widget.photoBuilder(h, height: 140),
                          ),
                        ),
                      if (h.mapLink != null || h.address != null) widget.locationBuilder(h, 4, small: false),
                    ],
                  ),
          ),
      ],
    );
  }
}

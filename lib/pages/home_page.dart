import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config.dart';
import '../services/api.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/ad_carousel.dart';
import '../widgets/common.dart';
import '../widgets/sync_banner.dart';
import '../widgets/progress.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _error = false;
  List<Ad> _ads = [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _fetch();
    _loadAds();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final d = await Api.instance.publicDashboard(AppConfig.campaignId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _data == null;
        _loading = false;
      });
    }
  }

  Future<void> _loadAds() async {
    try {
      final ads = await Api.instance.activeAds();
      if (mounted) setState(() => _ads = ads);
    } catch (_) {}
  }

  /// Same rule as the web app: mobile banners + left + right ads, mobile image only.
  List<Ad> get _mobileAds {
    List<Ad> pos(String p) => _ads.where((a) => a.position == p).toList();
    return [...pos('MOBILE_BOTTOM'), ...pos('LEFT'), ...pos('RIGHT')]
        .where((a) => a.mobileImageUrl != null)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = app.t;
    final pct = ((_data?['percentage'] ?? 0) as num).toDouble().clamp(0.0, 100.0);
    final screen = MediaQuery.of(context).size;
    final ringSize = math.min(screen.width * 0.66, 280.0);
    final ads = _mobileAds;

    return PageShell(
      child: RefreshIndicator(
        color: C.maroon,
        onRefresh: () async {
          await Future.wait([_fetch(), _loadAds()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            const SyncBanner(),
            // Title block with dynamic language switching
            Text(
              app.isTamil
                  ? 'ஒரு கோடி கந்த சஷ்டி கவசம் பாராயணம்'
                  : 'One crore chanting sessions of Kanda Shasti Kavacham',
              textAlign: TextAlign.center,
              style: app.isTamil
                  ? tamil(17, color: C.orange, weight: FontWeight.w700, height: 1.35)
                  : display(16, color: C.orange, weight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              app.isTamil
                  ? 'தமிழ்நாட்டின் வளர்ச்சி, வளம் மற்றும் செழிப்பிற்காக'
                  : 'For the growth, wealth, and prosperity of Tamil Nadu',
              textAlign: TextAlign.center,
              style: app.isTamil
                  ? tamil(12.5, color: C.maroon.withOpacity(0.8))
                  : body(12.5, color: C.maroon.withOpacity(0.8)),
            ),
            const SizedBox(height: 4),
            Text(
              app.isTamil
                  ? 'வெற்றி வேல்! வீர வேல்!'
                  : 'Vetri Vel! Veera Vel!',
              textAlign: TextAlign.center,
              style: app.isTamil
                  ? tamil(14, weight: FontWeight.w700)
                  : body(14, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(t('home.title'), textAlign: TextAlign.center, style: display(28, height: 1.1)),
            const SizedBox(height: 4),
            Text(t('home.subtitle'),
                textAlign: TextAlign.center, style: display(15, color: C.maroon.withOpacity(0.75))),
            const SizedBox(height: 16),

            // Ring
            Center(child: _ring(app, ringSize, pct)),
            const SizedBox(height: 16),

            // Stats band
            _StatsBand(
              loading: _loading,
              items: [
                (t('home.participants'), _data?['participants'], C.maroon),
                (t('home.remaining'), _data?['remaining'], C.orange),
                (t('home.target'), _data?['target'], C.blue),
              ],
            ),
            const SizedBox(height: 16),

            // Join
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: PrimaryButton(
                  label: t('home.join'),
                  onPressed: () => Navigator.of(context).pushNamed('/participate'),
                ),
              ),
            ),
            if (_data != null) ...[
              const SizedBox(height: 10),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: body(13, color: C.maroon.withOpacity(0.65)),
                    children: [
                      TextSpan(
                          text: fmt(_data!['participants'] as num?),
                          style: body(13, color: C.blue, weight: FontWeight.w700)),
                      TextSpan(text: ' ${t('home.devoteesJoined')}'),
                    ],
                  ),
                ),
              ),
            ],

            // Ad space (1200 × 800), rotating every 5s. Uses the API's mobile
            // ads like the web app; shows a placeholder when there are none.
            const SizedBox(height: 18),
            if (ads.isNotEmpty)
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  border: Border.all(color: C.gold.withOpacity(0.7), width: 2),
                ),
                child: AspectRatio(
                  aspectRatio: 1200 / 800,
                  child: AdCarousel(items: ads, label: 'Sponsors'),
                ),
              )
            else
              const AspectRatio(aspectRatio: 1200 / 800, child: _AdPlaceholder()),
            // Bundled backup ads, disabled for now in favour of the placeholder:
            // else
            //   const AspectRatio(
            //     aspectRatio: 1200 / 800,
            //     child: AdCarousel(items: _staticAds, fit: BoxFit.contain),
            //   ),

            // Footer
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(t('home.initiative'),
                      style: body(10.5, color: C.maroon.withOpacity(0.6))),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t('home.techPartner'),
                        style: body(10.5, color: C.maroon.withOpacity(0.6))),
                    const SizedBox(width: 6),
                    Image.asset(
                      'assets/images/RiceHRLogo.png',
                      width: 56,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text('RiceHR',
                          style: body(11, color: C.maroon, weight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(AppState app, double size, double pct) {
    if (_loading) {
      return Skeleton(width: size, height: size, radius: size / 2);
    }
    if (_error || _data == null) {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.6),
          border: Border.all(color: C.gold.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(app.t('home.liveUnavailable'),
                textAlign: TextAlign.center, style: display(16)),
            const SizedBox(height: 6),
            Text(app.t('home.refreshPage'),
                textAlign: TextAlign.center,
                style: body(11, color: C.maroon.withOpacity(0.65))),
          ],
        ),
      );
    }
    return SixfoldRing(
      size: size,
      pct: pct,
      completed: (_data!['completed'] ?? 0) as num,
      completedLabel: app.t('home.completed'),
      ofTargetLabel: app.t('home.ofTarget'),
    );
  }
}

// /// Bundled ads for the fixed 1200 × 800 slot. Shown with BoxFit.contain so
// /// contact details at the image edges are never cropped.
// const _staticAds = [
//   Ad(
//     id: -1,
//     position: 'STATIC',
//     mobileImageUrl: 'assets/images/ad_infiniteseva.png',
//     linkUrl: 'https://www.infiniteseva.org',
//   ),
//   Ad(
//     id: -2,
//     position: 'STATIC',
//     mobileImageUrl: 'assets/images/ad_ricehr.png',
//     linkUrl: 'https://www.ricehr.com',
//   ),
//   Ad(
//     id: -3,
//     position: 'STATIC',
//     mobileImageUrl: 'assets/images/ad_temples.png',
//     linkUrl: 'https://www.infiniteseva.org',
//   ),
// ];

/// Empty ad slot, matching the web app's AdPlaceholder.
class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(color: C.goldDark.withOpacity(0.5)),
      child: Container(
        color: Colors.white.withOpacity(0.6),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ad space', style: display(18)),
            const SizedBox(height: 4),
            Text('1200 × 800 px', style: body(14, color: C.blue, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Horizontal image', style: body(12, color: C.maroon.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0, dash = 6.0, gap = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    final path = Path()..addRect(Rect.fromLTWH(1, 1, size.width - stroke, size.height - stroke));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

class _StatsBand extends StatelessWidget {
  final bool loading;
  final List<(String, dynamic, Color)> items;
  const _StatsBand({required this.loading, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.gold.withOpacity(0.4)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: C.gold.withOpacity(0.4)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Column(
                    children: [
                      if (loading)
                        const Skeleton(width: 60, height: 22)
                      else
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(fmt(items[i].$2 as num?),
                              style: display(22, color: items[i].$3)),
                        ),
                      const SizedBox(height: 4),
                      Text(items[i].$1,
                          textAlign: TextAlign.center,
                          style: body(11.5, color: C.maroon.withOpacity(0.6))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
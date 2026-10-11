import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../config.dart';
import '../services/api.dart';
import '../services/app_state.dart';
import '../services/offline_queue.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

enum Stage { idle, choosingType, teamCapture, running, submitting, success, savedOffline, error }

class _Loc {
  final double latitude;
  final double longitude;
  final int accuracy;
  final String addressName;
  const _Loc(this.latitude, this.longitude, this.accuracy, this.addressName);
}

class ParticipatePage extends StatefulWidget {
  const ParticipatePage({super.key});

  @override
  State<ParticipatePage> createState() => _ParticipatePageState();
}

class _ParticipatePageState extends State<ParticipatePage> {
  Stage _stage = Stage.idle;
  String? _type; // INDIVIDUAL | TEAM

  DateTime? _start;
  DateTime? _end;
  int _duration = 0;
  int _elapsed = 0;
  Timer? _tick;

  Uint8List? _photoBytes;
  String _photoMime = 'image/jpeg';
  _Loc? _location;
  String _locationError = '';
  bool _capturing = false;
  final _teamCtrl = TextEditingController();

  String _errorMsg = '';
  Map<String, dynamic>? _result;
  String? _key;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppState.instance.user == null && mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _teamCtrl.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ───────────── choose type ─────────────
  void _chooseIndividual() {
    _type = 'INDIVIDUAL';
    _startTimer();
  }

  void _chooseTeam() {
    setState(() {
      _type = 'TEAM';
      _stage = Stage.teamCapture;
    });
    _captureLocation();
  }

  // ───────────── location ─────────────
  Future<void> _captureLocation() async {
    final t = AppState.instance.t;
    setState(() {
      _capturing = true;
      _locationError = '';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'disabled';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationError = t('participate.locDenied');
          _capturing = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final name = await _reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _location = _Loc(pos.latitude, pos.longitude, pos.accuracy.round(), name);
        _capturing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationError = t('participate.locFailed');
        _capturing = false;
      });
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
      final res = await http.get(uri, headers: {
        'Accept-Language': 'en',
        'User-Agent': 'InfiniteSevaApp/1.0',
      }).timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = (data['address'] as Map?)?.cast<String, dynamic>() ?? {};

      String? pick(List<String> keys) {
        for (final k in keys) {
          final v = addr[k]?.toString();
          if (v != null && v.isNotEmpty) return v;
        }
        return null;
      }

      final locality = pick(
          ['neighbourhood', 'suburb', 'quarter', 'hamlet', 'village', 'town', 'city_district', 'city']);
      final city = pick(['city', 'town', 'village']) ?? '';
      final state = addr['state']?.toString() ?? '';
      final parts = <String>{
        if (locality != null) locality,
        if (city.isNotEmpty) city,
        if (state.isNotEmpty) state,
      }.toList();
      return parts.isNotEmpty ? parts.join(', ') : (data['display_name']?.toString() ?? '');
    } catch (_) {
      return '';
    }
  }

  // ───────────── photo ─────────────
  Future<void> _pickPhoto() async {
    final t = AppState.instance.t;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: C.maroon),
              title: Text(t('participate.camera'), style: body(15)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: C.maroon),
              title: Text(t('participate.gallery'), style: body(15)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() => _errorMsg = t('participate.photoTooBig'));
        return;
      }
      final name = file.name.toLowerCase();
      setState(() {
        _photoBytes = bytes;
        _photoMime = name.endsWith('.png')
            ? 'image/png'
            : name.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg';
        _errorMsg = '';
      });
    } catch (_) {
      // user cancelled / permission denied
    }
  }

  void _teamContinue() {
    final t = AppState.instance.t;
    final size = int.tryParse(_teamCtrl.text.trim());
    if (_photoBytes == null) {
      setState(() => _errorMsg = t('participate.photoRequired'));
      return;
    }
    if (_location == null) {
      setState(() => _errorMsg = t('participate.locationRequired'));
      return;
    }
    if (size == null || size < 2 || size > 100) {
      setState(() => _errorMsg = t('participate.membersRequired'));
      return;
    }
    setState(() => _errorMsg = '');
    _startTimer();
  }

  // ───────────── timer ─────────────
  void _startTimer() {
    _start = DateTime.now();
    _end = null;
    _elapsed = 0;
    _key = null;
    try {
      WakelockPlus.enable();
    } catch (_) {}
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_start == null) return;
      setState(() => _elapsed = DateTime.now().difference(_start!).inSeconds);
    });
    setState(() => _stage = Stage.running);
  }

  void _stopTimer() {
    _tick?.cancel();
    _tick = null;
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  // ───────────── submit ─────────────
  Future<void> _submit() async {
    if (_stage == Stage.submitting) return;
    final user = AppState.instance.user;
    if (user == null || _start == null) return;

    _stopTimer();
    // Keep the same end time + idempotency key on retries so the server dedupes.
    if (_end == null) {
      _end = DateTime.now();
      _duration = _end!.difference(_start!).inSeconds;
      _elapsed = _duration;
    }
    _key ??= const Uuid().v4();

    setState(() {
      _stage = Stage.submitting;
      _errorMsg = '';
    });

    final isTeam = _type == 'TEAM';
    final payload = <String, dynamic>{
      'startTime': _start!.toUtc().toIso8601String(),
      'endTime': _end!.toUtc().toIso8601String(),
      'durationSeconds': _duration,
      'type': _type,
      'latitude': _location?.latitude,
      'longitude': _location?.longitude,
      'locationAddress': _location?.addressName,
      'photoBase64': _photoBytes != null
          ? 'data:$_photoMime;base64,${base64Encode(_photoBytes!)}'
          : null,
      'photoMime': _photoBytes != null ? _photoMime : null,
      'teamSize': isTeam ? int.tryParse(_teamCtrl.text.trim()) : null,
    };

    try {
      final res = await Api.instance.submitRecitation(
        userId: user.id,
        idempotencyKey: _key!,
        payload: payload,
      );
      if (!mounted) return;
      _key = null;
      setState(() {
        _result = res;
        _stage = Stage.success;
      });
    } on ApiException catch (e) {
      if (e.isTransient) {
        // No internet / server down: keep it on the phone and send it later
        // with the same key, so it is counted exactly once.
        try {
          await RecitationQueue.instance
              .add(key: _key!, userId: user.id, payload: payload);
          if (!mounted) return;
          _key = null;
          setState(() => _stage = Stage.savedOffline);
          return;
        } catch (_) {
          // Could not save locally either; fall through to the error screen.
        }
      }
      if (!mounted) return;
      setState(() {
        _errorMsg = (e.isTransient || e.message.isEmpty)
            ? AppState.instance.t('participate.submitError')
            : e.message;
        _stage = Stage.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = AppState.instance.t('participate.submitError');
        _stage = Stage.error;
      });
    }
  }

  void _cancel() {
    _stopTimer();
    setState(() {
      _start = null;
      _end = null;
      _elapsed = 0;
      _type = null;
      _photoBytes = null;
      _location = null;
      _locationError = '';
      _teamCtrl.clear();
      _errorMsg = '';
      _key = null;
      _stage = Stage.idle;
    });
  }

  // ───────────── UI ─────────────
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return PageShell(
      child: ScrollCenter(
        child: GoldCard(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(key: ValueKey(_stage), child: _content(app)),
          ),
        ),
      ),
    );
  }

  Widget _content(AppState app) {
    switch (_stage) {
      case Stage.idle:
        return _idle(app);
      case Stage.choosingType:
        return _choosing(app);
      case Stage.teamCapture:
        return _teamCapture(app);
      case Stage.running:
        return _running(app);
      case Stage.submitting:
        return _submitting(app);
      case Stage.success:
        return _success(app);
      case Stage.savedOffline:
        return _savedOffline(app);
      case Stage.error:
        return _errorView(app);
    }
  }

  Widget _pill(String text, {Widget? leading}) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: C.blue.withOpacity(0.07),
            border: Border.all(color: C.blue.withOpacity(0.25)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Text(text, style: body(12, color: C.blue, weight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Widget _idle(AppState app) {
    final t = app.t;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill('${t('participate.batch')} ${AppConfig.batchNumber}'),
        const SizedBox(height: 14),
        Text('பாராயணம் தொடங்கலாம்',
            textAlign: TextAlign.center,
            style: tamil(17, color: C.orange, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(t('participate.start'),
            textAlign: TextAlign.center, style: display(28, height: 1.15)),
        const SizedBox(height: 14),
        Text(t('participate.startSubtitle'),
            textAlign: TextAlign.center,
            style: body(14, color: C.maroon.withOpacity(0.7), height: 1.5)),
        const SizedBox(height: 24),
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [C.gold, C.goldDark]),
          ),
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: C.cream),
            alignment: Alignment.center,
            child: Text('▶', style: display(32, color: C.goldDark)),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: t('participate.startReading'),
          color: C.blue,
          onPressed: () => setState(() => _stage = Stage.choosingType),
        ),
        const SizedBox(height: 12),
        SecondaryButton(label: t('participate.notNow'), onPressed: () => goHome(context)),
      ],
    );
  }

  Widget _choosing(AppState app) {
    final t = app.t;
    Widget option(String emoji, String title, String desc, Color color, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.1)),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: display(18, color: color)),
                    const SizedBox(height: 2),
                    Text(desc, style: body(12, color: C.maroon.withOpacity(0.6))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t('participate.chooseType'),
            textAlign: TextAlign.center, style: display(24, height: 1.2)),
        const SizedBox(height: 8),
        Text(t('participate.chooseTypeSub'),
            style: body(14, color: C.maroon.withOpacity(0.65))),
        const SizedBox(height: 24),
        option('🧘', t('participate.individual'), t('participate.individualDesc'), C.blue,
            _chooseIndividual),
        const SizedBox(height: 14),
        option('👥', t('participate.team'), t('participate.teamDesc'), C.goldDark, _chooseTeam),
        const SizedBox(height: 20),
        SecondaryButton(
            label: t('participate.cancel'),
            onPressed: () => setState(() => _stage = Stage.idle)),
      ],
    );
  }

  Widget _sectionLabel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text,
              style: body(10.5, color: C.maroon.withOpacity(0.6), weight: FontWeight.w800)
                  .copyWith(letterSpacing: 1.2)),
        ),
      );

  Widget _teamCapture(AppState app) {
    final t = app.t;
    final canContinue = _photoBytes != null && _location != null && _teamCtrl.text.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t('participate.teamTitle'),
            textAlign: TextAlign.center, style: display(24, height: 1.2)),
        const SizedBox(height: 8),
        Text(t('participate.teamSub'),
            textAlign: TextAlign.center, style: body(14, color: C.maroon.withOpacity(0.65))),
        const SizedBox(height: 20),

        _sectionLabel('👥 ${t('participate.totalMembers')}'),
        TextField(
          controller: _teamCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 3,
          style: body(16, color: Colors.black87, weight: FontWeight.w700),
          onChanged: (v) {
            final d = onlyDigits(v, 3);
            if (d != v) {
              _teamCtrl.value = TextEditingValue(
                text: d,
                selection: TextSelection.collapsed(offset: d.length),
              );
            }
            setState(() {});
          },
          decoration: inputDeco(hint: t('participate.membersPlaceholder')).copyWith(
            counterText: '',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: C.gold.withOpacity(0.4), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: C.gold, width: 2),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(t('participate.totalMembersHint'),
                style: body(10.5, color: C.neutral500)),
          ),
        ),
        const SizedBox(height: 20),

        _sectionLabel('📷 ${t('participate.photo')}'),
        if (_photoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.memory(_photoBytes!, width: double.infinity, height: 190, fit: BoxFit.cover),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Material(
                    color: Colors.white.withOpacity(0.9),
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: _pickPhoto,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(t('participate.retake'),
                            style: body(12, weight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickPhoto,
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: C.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: C.gold.withOpacity(0.5), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📷', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(t('participate.takePhoto'), style: body(14, weight: FontWeight.w600)),
                  Text(t('participate.orGallery'),
                      style: body(12, color: C.maroon.withOpacity(0.5))),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),

        _sectionLabel('📍 ${t('participate.location')}'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _location != null ? const Color(0xFFECFDF5) : C.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _location != null ? const Color(0xFF6EE7B7) : C.gold.withOpacity(0.4),
                width: 2),
          ),
          child: _locationBody(t),
        ),

        if (_errorMsg.isNotEmpty) ...[
          const SizedBox(height: 16),
          ErrorBox(_errorMsg),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: t('participate.continue'),
          onPressed: canContinue ? _teamContinue : null,
        ),
        const SizedBox(height: 12),
        SecondaryButton(label: t('participate.cancel'), onPressed: _cancel),
      ],
    );
  }

  Widget _locationBody(String Function(String) t) {
    const green = Color(0xFF065F46);
    if (_capturing) {
      return Row(
        children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: C.goldDark)),
          const SizedBox(width: 10),
          Text(t('participate.fetchingLocation'),
              style: body(13.5, color: C.maroon.withOpacity(0.6))),
        ],
      );
    }
    if (_location != null) {
      final l = _location!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${t('participate.locationCaptured')} ✓',
              style: body(14, color: green, weight: FontWeight.w700)),
          if (l.addressName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('📍 ${l.addressName}',
                  style: body(13.5, color: green, weight: FontWeight.w500)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${l.latitude.toStringAsFixed(5)}, ${l.longitude.toStringAsFixed(5)}  (± ${l.accuracy}m)',
              style: body(10.5, color: C.neutral500),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_locationError.isNotEmpty ? _locationError : t('participate.locationNotAvail'),
            style: body(13.5, color: C.maroon.withOpacity(0.6))),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _captureLocation,
          child: Text(t('participate.tryAgain'),
              style: body(12, color: C.blue, weight: FontWeight.w700)
                  .copyWith(decoration: TextDecoration.underline)),
        ),
      ],
    );
  }

  Widget _running(AppState app) {
    final t = app.t;
    final isTeam = _type == 'TEAM';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill(
          isTeam
              ? '${t('participate.teamReading')} (${_teamCtrl.text})'
              : t('participate.readingProgress'),
          leading: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle)),
        ),
        const SizedBox(height: 14),
        Text('பாராயணம் நடைபெறுகிறது',
            textAlign: TextAlign.center,
            style: tamil(17, color: C.orange, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(t('participate.continueReading'),
            textAlign: TextAlign.center, style: display(24, height: 1.2)),
        const SizedBox(height: 28),
        Text(t('participate.timeElapsed').toUpperCase(),
            style: body(10.5, color: C.maroon.withOpacity(0.6), weight: FontWeight.w800)
                .copyWith(letterSpacing: 3)),
        const SizedBox(height: 12),
        FittedBox(
          child: Text(fmtDurationClock(_elapsed),
              style: display(56, color: C.goldDark, height: 1).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        const SizedBox(height: 28),
        PrimaryButton(label: t('participate.finish'), onPressed: _submit),
        const SizedBox(height: 12),
        SecondaryButton(label: t('participate.cancelReset'), onPressed: _cancel),
      ],
    );
  }

  Widget _submitting(AppState app) {
    final t = app.t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 4, color: C.goldDark),
          ),
          const SizedBox(height: 24),
          Text(t('participate.recording'), textAlign: TextAlign.center, style: display(22)),
          const SizedBox(height: 8),
          Text('${t('participate.duration')}: ${fmtDurationClock(_elapsed)}',
              style: body(13.5, color: C.maroon.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _success(AppState app) {
    final t = app.t;
    final r = _result ?? {};
    final isTeam = _type == 'TEAM';

    Widget figure(String label, String value, Color color) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: Column(
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: display(22, color: color))),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    style: body(11, color: C.maroon.withOpacity(0.6))),
              ],
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [C.gold, C.goldDark]),
          ),
          child: const Icon(Icons.check_rounded, color: C.cream, size: 44),
        ),
        const SizedBox(height: 18),
        Text('வேலுண்டு வினையில்லை!',
            style: tamil(17, color: C.orange, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(t('participate.counted'),
            textAlign: TextAlign.center, style: display(28, height: 1.15)),
        const SizedBox(height: 10),
        Text(
          '${isTeam ? '👥 ${t('participate.team')} (${_teamCtrl.text})' : '🧘 ${t('participate.individual')}'}'
          ' · ${t('participate.duration')}: ${fmtDurationClock(_elapsed)}',
          textAlign: TextAlign.center,
          style: body(13.5, color: C.maroon.withOpacity(0.65)),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: C.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.gold.withOpacity(0.4)),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                figure(t('participate.added'), '+${fmt(r['contribution'] as num?)}', C.goldDark),
                VerticalDivider(width: 1, color: C.gold.withOpacity(0.4)),
                figure(t('participate.yourTotal'), fmt(r['myTotal'] as num?), C.blue),
                VerticalDivider(width: 1, color: C.gold.withOpacity(0.4)),
                figure(t('participate.everyone'), fmt(r['campaignTotal'] as num?), C.orange),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: t('participate.seeDashboard'),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/dashboard'),
        ),
        const SizedBox(height: 12),
        SecondaryButton(label: t('participate.backHome'), onPressed: () => goHome(context)),
      ],
    );
  }

  Widget _savedOffline(AppState app) {
    final t = app.t;
    final isTeam = _type == 'TEAM';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [C.gold, C.goldDark]),
          ),
          child: const Icon(Icons.cloud_upload_outlined, color: C.cream, size: 40),
        ),
        const SizedBox(height: 18),
        Text(t('participate.savedOffline'),
            textAlign: TextAlign.center, style: display(26, height: 1.15)),
        const SizedBox(height: 10),
        Text(
          '${isTeam ? '👥 ${t('participate.team')} (${_teamCtrl.text})' : '🧘 ${t('participate.individual')}'}'
          ' · ${t('participate.duration')}: ${fmtDurationClock(_elapsed)}',
          textAlign: TextAlign.center,
          style: body(13.5, color: C.maroon.withOpacity(0.65)),
        ),
        const SizedBox(height: 14),
        Text(t('participate.savedOfflineSub'),
            textAlign: TextAlign.center,
            style: body(14, color: C.maroon.withOpacity(0.7), height: 1.5)),
        const SizedBox(height: 24),
        PrimaryButton(label: t('participate.backHome'), onPressed: () => goHome(context)),
      ],
    );
  }

  Widget _errorView(AppState app) {
    final t = app.t;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: C.maroon.withOpacity(0.08),
            border: Border.all(color: C.maroon.withOpacity(0.2)),
          ),
          child: const Icon(Icons.error_outline, color: C.maroon, size: 32),
        ),
        const SizedBox(height: 18),
        Text(t('participate.notRecorded'),
            textAlign: TextAlign.center, style: display(24, height: 1.2)),
        const SizedBox(height: 12),
        Text(_errorMsg,
            textAlign: TextAlign.center,
            style: body(14, color: C.maroon.withOpacity(0.7), height: 1.5)),
        const SizedBox(height: 24),
        PrimaryButton(label: t('participate.tryAgain'), onPressed: _submit),
        const SizedBox(height: 12),
        SecondaryButton(label: t('participate.startOver'), onPressed: _cancel),
      ],
    );
  }
}

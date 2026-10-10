import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api.dart';
import '../services/app_state.dart';
import '../theme.dart';
import '../widgets/ad_carousel.dart';
import '../widgets/common.dart';

const _positions = ['LEFT', 'RIGHT', 'MOBILE_BOTTOM', 'TOP_BANNER'];
const _maxImageBytes = 2 * 1024 * 1024;

class AdminAdsPage extends StatefulWidget {
  const AdminAdsPage({super.key});

  @override
  State<AdminAdsPage> createState() => _AdminAdsPageState();
}

class _AdminAdsPageState extends State<AdminAdsPage> {
  final _title = TextEditingController();
  final _link = TextEditingController();
  final _order = TextEditingController(text: '0');
  final _picker = ImagePicker();

  String _position = 'LEFT';
  bool _active = true;
  String? _desktopImage; // data URL or existing URL
  String? _mobileImage;
  bool _desktopChanged = false;
  bool _mobileChanged = false;
  int? _editingId;

  List<Ad> _ads = [];
  bool _loading = true;
  bool _saving = false;
  String _error = '';
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    final user = AppState.instance.user;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (user == null) {
        Navigator.of(context).pushReplacementNamed('/login');
      } else if (!user.isAdmin) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    });
    _allowed = user != null && user.isAdmin;
    if (_allowed) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _link.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ads = await Api.instance.allAds();
      if (!mounted) return;
      setState(() {
        _ads = ads;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<String?> _pick() async {
    final t = AppState.instance.t;
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
    if (f == null) return null;
    final bytes = await f.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      setState(() => _error = t('admin.imageTooBig'));
      return null;
    }
    final name = f.path.toLowerCase();
    final mime = name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    setState(() => _error = '');
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  void _reset() {
    _title.clear();
    _link.clear();
    _order.text = '0';
    _position = 'LEFT';
    _active = true;
    _desktopImage = null;
    _mobileImage = null;
    _desktopChanged = false;
    _mobileChanged = false;
    _editingId = null;
    _error = '';
  }

  void _startEdit(Ad a) {
    setState(() {
      _editingId = a.id;
      _position = _positions.contains(a.position) ? a.position : 'LEFT';
      _title.text = a.title ?? '';
      _link.text = a.linkUrl ?? '';
      _order.text = a.displayOrder.toString();
      _active = a.isActive;
      _desktopImage = a.imageUrl;
      _mobileImage = a.mobileImageUrl;
      _desktopChanged = false;
      _mobileChanged = false;
      _error = '';
    });
  }

  Future<void> _save() async {
    final t = AppState.instance.t;
    if (_desktopImage == null && _mobileImage == null) {
      setState(() => _error = t('admin.imageRequired'));
      return;
    }
    final payload = <String, dynamic>{
      'position': _position,
      'title': _title.text.trim(),
      'link_url': _link.text.trim(),
      'display_order': int.tryParse(_order.text.trim()) ?? 0,
      'is_active': _active ? 1 : 0,
    };
    final editing = _editingId != null;
    if (!editing || _desktopChanged) payload['image_url'] = _desktopImage ?? '';
    if (!editing || _mobileChanged) payload['mobile_image_url'] = _mobileImage ?? '';

    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      if (editing) {
        await Api.instance.updateAd(_editingId!, payload);
      } else {
        await Api.instance.createAd(payload);
      }
      if (!mounted) return;
      setState(_reset);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(Ad a) async {
    try {
      await Api.instance.updateAd(a.id, {'is_active': a.isActive ? 0 : 1});
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _delete(Ad a) async {
    final t = AppState.instance.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('admin.deleteConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('admin.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('admin.delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.deleteAd(a.id);
      if (_editingId == a.id) setState(_reset);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = app.t;
    if (!_allowed) {
      return const Scaffold(backgroundColor: C.cream, body: Center(child: CircularProgressIndicator()));
    }

    return PageShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(t('admin.title'), style: display(22)),
          const SizedBox(height: 12),
          GoldCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_editingId == null ? t('admin.addNew') : t('admin.editAd'),
                    style: body(16, weight: FontWeight.w700)),
                const SizedBox(height: 12),
                _label(t('admin.position')),
                DropdownButtonFormField<String>(
                  value: _position,
                  decoration: inputDeco(),
                  items: [
                    for (final p in _positions) DropdownMenuItem(value: p, child: Text(p)),
                  ],
                  onChanged: (v) => setState(() => _position = v ?? 'LEFT'),
                ),
                const SizedBox(height: 12),
                _label(t('admin.displayOrder')),
                TextField(
                  controller: _order,
                  keyboardType: TextInputType.number,
                  style: body(16, color: Colors.black87),
                  decoration: inputDeco(),
                ),
                const SizedBox(height: 12),
                _label(t('admin.titleLabel')),
                TextField(
                  controller: _title,
                  style: body(16, color: Colors.black87),
                  decoration: inputDeco(hint: t('admin.titlePlaceholder')),
                ),
                const SizedBox(height: 12),
                _label(t('admin.linkUrl')),
                TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  style: body(16, color: Colors.black87),
                  decoration: inputDeco(hint: 'https://'),
                ),
                const SizedBox(height: 12),
                _imageField(
                  '${t('admin.desktopImage')} ${t('admin.desktopImageSub')}',
                  t('admin.recommendedDesktop'),
                  _desktopImage,
                  onPick: () async {
                    final v = await _pick();
                    if (v != null) {
                      setState(() {
                        _desktopImage = v;
                        _desktopChanged = true;
                      });
                    }
                  },
                  onRemove: () => setState(() {
                    _desktopImage = null;
                    _desktopChanged = true;
                  }),
                ),
                const SizedBox(height: 12),
                _imageField(
                  '${t('admin.mobileImage')} ${t('admin.mobileImageSub')}',
                  t('admin.recommendedMobile'),
                  _mobileImage,
                  onPick: () async {
                    final v = await _pick();
                    if (v != null) {
                      setState(() {
                        _mobileImage = v;
                        _mobileChanged = true;
                      });
                    }
                  },
                  onRemove: () => setState(() {
                    _mobileImage = null;
                    _mobileChanged = true;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: C.maroon,
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: Text(t('admin.active'), style: body(14)),
                ),
                if (_error.isNotEmpty) ...[ErrorBox(_error), const SizedBox(height: 10)],
                PrimaryButton(
                  label: _editingId == null ? t('admin.create') : t('admin.update'),
                  busy: _saving,
                  onPressed: _save,
                ),
                if (_editingId != null) ...[
                  const SizedBox(height: 8),
                  SecondaryButton(label: t('admin.cancel'), onPressed: () => setState(_reset)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(t('admin.allAds'), style: display(18)),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_ads.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t('admin.noAds'), style: body(14, color: C.neutral500)),
            )
          else
            for (final a in _ads) _adTile(a, t),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s, style: body(13.5, color: C.neutral700, weight: FontWeight.w700)),
      );

  Widget _imageField(String label, String hint, String? src,
      {required VoidCallback onPick, required VoidCallback onRemove}) {
    final t = AppState.instance.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        if (src != null)
          Container(
            height: 120,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.gold.withOpacity(0.6)),
              color: Colors.white,
            ),
            child: AdImage(src: src, fit: BoxFit.contain),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(t('admin.chooseImage')),
            ),
            if (src != null)
              TextButton(
                onPressed: onRemove,
                child: Text(t('admin.remove'), style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
        Text(hint, style: body(11, color: C.neutral500)),
      ],
    );
  }

  Widget _adTile(Ad a, String Function(String) t) {
    final thumb = a.mobileImageUrl ?? a.imageUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(a.isActive ? 0.9 : 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.gold.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: C.neutral200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: thumb == null ? null : AdImage(src: thumb),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (a.title ?? '').isEmpty ? t('admin.noTitle') : a.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(14, weight: FontWeight.w700),
                ),
                Text('${a.position} · ${t('admin.order')} ${a.displayOrder}',
                    style: body(12, color: C.neutral500)),
                Text(
                  [
                    if (a.imageUrl != null) t('admin.desktop'),
                    if (a.mobileImageUrl != null) t('admin.mobile'),
                  ].join(' · '),
                  style: body(12, color: C.neutral500),
                ),
                if (!a.isActive)
                  Text(t('admin.inactive'),
                      style: body(11, color: Colors.red, weight: FontWeight.w700)),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
                      onPressed: () => _startEdit(a),
                      child: Text(t('admin.edit')),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
                      onPressed: () => _toggle(a),
                      child: Text(a.isActive ? t('admin.disable') : t('admin.enable')),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
                      onPressed: () => _delete(a),
                      child: Text(t('admin.delete'), style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme.dart';
import '../util.dart';

/// Shows either a base64 data-URL image or a normal network image.
class AdImage extends StatefulWidget {
  final String src;
  final BoxFit fit;
  const AdImage({super.key, required this.src, this.fit = BoxFit.cover});

  @override
  State<AdImage> createState() => _AdImageState();
}

class _AdImageState extends State<AdImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = decodeDataUrl(widget.src);
  }

  @override
  void didUpdateWidget(covariant AdImage old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src) _bytes = decodeDataUrl(widget.src);
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(_bytes!,
          fit: widget.fit, gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox.shrink());
    }
    return Image.network(widget.src,
        fit: widget.fit, errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }
}

/// Auto-rotating (5s) ad slider. Uses the mobile image only, like the web app.
class AdCarousel extends StatefulWidget {
  final List<Ad> items;
  final String label;
  const AdCarousel({super.key, required this.items, this.label = ''});

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (widget.items.length <= 1 || !_controller.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.items.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            final ad = widget.items[i];
            final src = ad.mobileImageUrl;
            return GestureDetector(
              onTap: ad.linkUrl != null ? () => openUrl(ad.linkUrl!) : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  src != null
                      ? AdImage(src: src)
                      : Container(
                          color: Colors.white.withOpacity(0.4),
                          alignment: Alignment.center,
                          child: Text('No mobile image',
                              style: body(12, color: C.maroon.withOpacity(0.6))),
                        ),
                  if (ad.title != null && ad.title!.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 24, 12, 22),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xB3000000), Colors.transparent],
                          ),
                        ),
                        child: Text(ad.title!,
                            style: body(12, color: Colors.white, weight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (widget.label.isNotEmpty)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(widget.label.toUpperCase(),
                  style: body(9, color: Colors.white, weight: FontWeight.w700)),
            ),
          ),
        if (widget.items.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 6,
                    width: i == _index ? 16 : 6,
                    decoration: BoxDecoration(
                      color: i == _index ? C.gold : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class MxcImage extends StatefulWidget {
  final Uri? uri;
  final Event? event;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final bool isThumbnail;
  final Duration retryDuration;
  final Widget Function(BuildContext context)? placeholder;
  final String? cacheKey;
  final Client? client;

  const MxcImage({
    this.uri,
    this.event,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.isThumbnail = true,
    this.retryDuration = const Duration(seconds: 2),
    this.cacheKey,
    this.client,
    super.key,
  });

  @override
  State<MxcImage> createState() => _MxcImageState();
}

class _MxcImageState extends State<MxcImage> {
  Uint8List? _imageData;

  Future<void> _load() async {
    final event = widget.event;

    if (event != null) {
      final data = await event.downloadAndDecryptAttachment(
        getThumbnail: widget.isThumbnail,
      );
      if (data.msgType == "m.image") {
        if (!mounted) return;
        setState(() {
          _imageData = data.bytes;
        });
        return;
      }
    }
  }

  void _tryLoad(_) async {
    try {
      await _load();
    } catch (_) {
      if (!mounted) return;
      await Future.delayed(widget.retryDuration);
      _tryLoad(_);
    }
  }

  @override
  void initState() {
    super.initState();
    _tryLoad(context);
  }

  Widget placeholder(BuildContext context) =>
      widget.placeholder?.call(context) ??
      Container(
        width: widget.width,
        height: widget.height,
        alignment: Alignment.center,
        child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
      );

  @override
  Widget build(BuildContext context) {
    final data = _imageData;
    final hasData = data != null && data.isNotEmpty;

    return AnimatedCrossFade(
      crossFadeState:
          hasData ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 128),
      firstChild: placeholder(context),
      secondChild: hasData
          ? Image.memory(
              data,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              filterQuality:
                  widget.isThumbnail ? FilterQuality.low : FilterQuality.medium,
              errorBuilder: (context, __, ___) {
                _imageData = null;
                WidgetsBinding.instance.addPostFrameCallback(_tryLoad);
                return placeholder(context);
              },
            )
          : SizedBox(
              width: widget.width,
              height: widget.height,
            ),
    );
  }
}

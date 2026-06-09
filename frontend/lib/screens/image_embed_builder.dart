import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:leevinote/utils/constants.dart';

class NoteImageEmbedBuilder extends EmbedBuilder {
  static final Map<String, double> _widthCache = {};

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final rawUrl = embedContext.node.value.data as String;
    final parts = rawUrl.split('#');
    final url = parts[0];
    final params = <String, String>{};
    if (parts.length > 1) {
      for (final p in parts[1].split('&')) {
        final kv = p.split('=');
        if (kv.length == 2) params[kv[0]] = kv[1];
      }
    }
    final cachedWidth = _widthCache[url];
    final widthStr = params['width'];
    final maxWidth = cachedWidth ?? (widthStr != null ? double.tryParse(widthStr) : null);

    Widget imageWidget;
    if (url.startsWith('local://')) {
      final path = url.substring('local://'.length);
      imageWidget = Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _errorWidget(),
      );
    } else if (url.startsWith('http')) {
      imageWidget = _networkImage(url);
    } else {
      imageWidget = _networkImage('${ApiConstants.baseUrl}/files/$url');
    }

    return GestureDetector(
      onLongPress: () => _showResizeDialog(context, url),
      onTap: () => _showImagePreview(context, url),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth) : null,
        child: imageWidget,
      ),
    );
  }

  Widget _networkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        final total = loadingProgress.expectedTotalBytes;
        final progress = total != null ? loadingProgress.cumulativeBytesLoaded / total : null;
        return SizedBox(
          height: 200,
          child: Center(
            child: CircularProgressIndicator(value: progress),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _errorWidget(),
    );
  }

  Widget _errorWidget() {
    return Container(
      height: 120,
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, size: 32, color: Colors.grey),
            SizedBox(height: 4),
            Text('图片加载失败', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _showResizeDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('图片大小'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('小 (200px)'),
              onTap: () {
                _widthCache[imageUrl] = 200;
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('中 (400px)'),
              onTap: () {
                _widthCache[imageUrl] = 400;
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('大 (600px)'),
              onTap: () {
                _widthCache[imageUrl] = 600;
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('原始大小'),
              onTap: () {
                _widthCache.remove(imageUrl);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            if (url.startsWith('local://'))
              InteractiveViewer(
                child: Image.file(File(url.substring('local://'.length))),
              )
            else
              InteractiveViewer(
                child: Image.network(
                  url.startsWith('http') ? url : '${ApiConstants.baseUrl}/files/$url',
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

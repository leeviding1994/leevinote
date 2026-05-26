import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:leevinote/utils/constants.dart';

class NoteImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final fullUrl = url.startsWith('http') ? url : '${ApiConstants.baseUrl}/files/$url';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Image.network(
        fullUrl,
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
        errorBuilder: (context, error, stackTrace) {
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
        },
      ),
    );
  }
}

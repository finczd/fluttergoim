import 'package:flutter/material.dart';

/// 全屏图片预览（微信看大图交互：黑底 + 双指/双击缩放 + 右上角关闭）
class ImageViewerPage extends StatefulWidget {
  final String url;
  const ImageViewerPage({super.key, required this.url});

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final _ctrl = TransformationController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _ctrl,
              minScale: 1,
              maxScale: 4,
              panEnabled: true,
              clipBehavior: Clip.none,
              child: Center(
                child: Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white70),
                        ),
                  errorBuilder: (_, __, ___) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_outlined,
                          size: 56, color: Colors.white54),
                      const SizedBox(height: 8),
                      Text('图片加载失败',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 右上角关闭按钮（黑底 + 半透明白圆钮，不用 emoji）
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: Colors.white24,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, size: 22, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

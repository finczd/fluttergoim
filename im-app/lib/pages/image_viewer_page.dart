import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../utils/image_saver.dart';
import '../widgets/app_dialogs.dart';

/// 全屏图片预览（微信看大图交互：黑底 + 双指/双击缩放 + 右上角关闭 +
/// 底部「保存到相册」胶囊按钮 / 长按大图保存）
class ImageViewerPage extends StatefulWidget {
  final String url;
  const ImageViewerPage({super.key, required this.url});

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final _ctrl = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 保存当前大图到相册，结果用轻提示反馈
  Future<void> _save() async {
    if (_saving) return;
    final t = AppLocalizations.of(context).t;
    setState(() => _saving = true);
    try {
      final ok = await ImageSaver.saveNetworkImage(widget.url);
      if (!mounted) return;
      AppDialogs.toast(
          context, ok ? t('momentsSaved') : t('momentsSaveFailed'));
    } catch (_) {
      if (mounted) AppDialogs.toast(context, t('momentsSaveFailed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
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
                child: GestureDetector(
                  // 长按大图 = 保存到相册（微信式）
                  onLongPress: _save,
                  child: Image.network(
                    widget.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white70),
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
          // 底部居中「保存到相册」半透明胶囊按钮（微信式）
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _saving ? null : _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_saving)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Icon(Icons.save_alt,
                                size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(t('momentsSaveToAlbum'),
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white)),
                        ],
                      ),
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

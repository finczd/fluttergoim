import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_locale.dart';

/// native 摄像头扫码（mobile_scanner）
/// - 先用 permission_handler 显式申请 CAMERA 权限。
/// - 非 ready 态（加载/权限/错误）一律不挂载 MobileScanner widget：
///   重试时先把 UI 切出 ready 态（旧相机 widget 随帧卸载），再 dispose 旧
///   controller，避免 controller 在 widget 仍挂载时被平台级销毁（竞态）。
/// - 每次重试都重新创建 MobileScannerController，避免旧 controller 在失败状态卡住。
/// - 被拒绝/永久拒绝：引导重新授权或去系统设置开启。
/// - init_failed 时在页面展示底层异常详情（errorCode + message），
///   便于区分「相机被其它应用（如 TRTC 通话）占用 / 无后摄 / 插件问题」。
class ScanCamera extends StatefulWidget {
  final ValueChanged<String> onScan;
  const ScanCamera({super.key, required this.onScan});

  @override
  State<ScanCamera> createState() => _ScanCameraState();
}

class _ScanCameraState extends State<ScanCamera> {
  MobileScannerController? _controller;
  String _lastError =
      ''; // '', 'permission_denied', 'permanently_denied', 'init_failed'
  String _lastErrorDetail = ''; // 底层异常详情（errorCode + message，截断 120 字符）
  bool _checkingPermission = true;
  int _autoRetry = 0; // 自动重试次数（CameraX 瞬时初始化失败很常见）
  bool _disposed = false; // 页面已销毁，所有异步回调 setState 前必须先判断
  bool _starting = false; // _start 并发守卫（errorBuilder 多次回调 / 连点重试）

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _disposed = true;
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  Future<void> _start({bool manual = true}) async {
    if (_starting || _disposed) return;
    _starting = true;
    try {
      if (manual) _autoRetry = 0;
      if (!mounted) return;

      // 先摘掉旧 controller：UI 立即离开 ready 态，MobileScanner 随之从树上卸载
      final old = _controller;
      setState(() {
        _checkingPermission = true;
        _lastError = '';
        _lastErrorDetail = '';
        _controller = null;
      });
      // 等一帧确保旧 MobileScanner widget 完成卸载，再做平台级 dispose；
      // 即使期间页面已销毁，也要把旧 controller 释放掉（否则泄漏）
      await WidgetsBinding.instance.endOfFrame;
      await old?.dispose();
      if (_disposed || !mounted) return;
      // 释放相机需要一点时间，给 CameraX 一个缓冲（国产 ROM 上 300ms 经常不够）
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (_disposed || !mounted) return;

      // 1. 先检查权限
      final status = await Permission.camera.status;
      if (_disposed || !mounted) return;
      if (status.isGranted) {
        _initScanner();
        return;
      }

      // 2. 申请权限
      final req = await Permission.camera.request();
      if (_disposed || !mounted) return;
      if (req.isGranted) {
        _initScanner();
      } else if (req.isPermanentlyDenied) {
        setState(() {
          _lastError = 'permanently_denied';
          _checkingPermission = false;
        });
      } else {
        setState(() {
          _lastError = 'permission_denied';
          _checkingPermission = false;
        });
      }
    } finally {
      _starting = false;
    }
  }

  void _initScanner() {
    if (_disposed || !mounted) return;
    _controller = MobileScannerController(
      autoStart: true,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    setState(() => _checkingPermission = false);
  }

  void _openSettings() => openAppSettings();

  /// 底层异常摘要，截断到 120 字符
  String _clipDetail(String text) {
    if (text.length <= 120) return text;
    return text.substring(0, 120);
  }

  /// 权限类错误判定：mobile_scanner 的 genericError 文案不含 permission/denied，
  /// 只有 permissionDenied / 系统拒绝类错误才会被识别为权限问题
  bool _isPermissionError(String message) {
    final msg = message.toLowerCase();
    return msg.contains('permission') || msg.contains('denied');
  }

  /// 摄像头错误：权限类直接报错；初始化类先自动重试 3 次再报错。
  /// 进入本方法后 UI 立即离开 ready 态（卸载 MobileScanner），
  /// 杜绝 errorBuilder 在错误态每次 rebuild 重复注册回调、重复调度重试。
  void _onCameraError(bool denied, String detail) {
    if (_disposed || !mounted) return;
    debugPrint('[Scan] camera error: $detail');
    if (denied) {
      if (_lastError == 'permission_denied') return; // 已在错误态，避免重复 setState
      setState(() {
        _lastError = 'permission_denied';
        _lastErrorDetail = _clipDetail(detail);
        _checkingPermission = false;
      });
      return;
    }
    // 已有重试/启动在途（UI 已切到加载态），忽略重复的错误回调
    if (_checkingPermission) return;
    if (_autoRetry < 3) {
      _autoRetry += 1;
      final delay = _autoRetry == 1 ? 800 : (_autoRetry == 2 ? 1800 : 3000);
      debugPrint('[Scan] auto retry #$_autoRetry in ${delay}ms');
      // 先切到加载态卸载相机 widget，再走干净的重试路径
      setState(() => _checkingPermission = true);
      Future<void>.delayed(Duration(milliseconds: delay), () {
        if (_disposed || !mounted) return;
        _start(manual: false);
      });
      return;
    }
    if (_lastError == 'init_failed') return; // 已在最终错误态
    setState(() {
      _lastError = 'init_failed';
      _lastErrorDetail = _clipDetail(detail);
      _checkingPermission = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    if (_checkingPermission) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    if (_lastError.isNotEmpty) {
      return _buildError(_lastError == 'permanently_denied');
    }

    final controller = _controller;
    if (controller == null) {
      return _buildError(false, customMessage: t('scanCamNotReady'));
    }

    // 只有 ready 态才挂载 MobileScanner
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            final detail = error.toString();
            final denied = _isPermissionError(detail);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onCameraError(denied, detail);
            });
            return _buildError(denied);
          },
        ),
        // 扫描框
        IgnorePointer(
          child: Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onDetect(BarcodeCapture capture) {
    final raw =
        capture.barcodes.isEmpty ? '' : (capture.barcodes.first.rawValue ?? '');
    if (raw.isNotEmpty) widget.onScan(raw);
  }

  Widget _buildError(bool permissionDenied, {String? customMessage}) {
    final t = AppLocalizations.of(context).t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_camera_outlined,
                size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              permissionDenied
                  ? t('scanCamPermissionDenied')
                  : (customMessage ?? t('scanCamInitFailed')),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              permissionDenied
                  ? t('scanCamPermissionHint')
                  : t('scanCamInitHint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 13, height: 1.5),
            ),
            // 排障辅助：显示底层真实错误（不进 i18n 词典，仅 init_failed 时出现）
            if (!permissionDenied &&
                customMessage == null &&
                _lastErrorDetail.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '错误详情：$_lastErrorDetail',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white24, fontSize: 11, height: 1.4),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: permissionDenied ? _openSettings : _start,
              icon: Icon(permissionDenied ? Icons.settings : Icons.refresh,
                  size: 18),
              label: Text(permissionDenied
                  ? t('scanCamOpenSettings')
                  : t('scanCamRetry')),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(180, 46),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

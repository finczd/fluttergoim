import 'package:flutter/material.dart';

/// Aura Messaging 设计系统（依据 D:\im-project\UI\DESIGN.md）
/// Telegram Blue 主色 + 现代极简，Inter 字体
class AppTheme {
  // ===== 色板（DESIGN.md Colors） =====
  static const Color primary = Color(0xFF0088CC); // Telegram Blue
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF007BB9);

  static const Color secondary = Color(0xFF00668A);
  static const Color secondaryContainer = Color(0xFF6ACCFF);

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF4F4F5);
  static const Color surfaceContainerLow = Color(0xFFF4F3F8);

  static const Color textPrimary = Color(0xFF1A1B1F);
  static const Color textSecondary = Color(0xFF3F4850);
  static const Color textTertiary = Color(0xFF8E9096);
  static const Color textLink = Color(0xFF0088CC);

  static const Color divider = Color(0xFFE9E7ED);

  // 业务扩展色
  static const Color success = Color(0xFF00B42A);
  static const Color warning = Color(0xFFFF7D00);
  static const Color danger = Color(0xFFBA1A1A);

  static const Color redPacket = Color(0xFFEE4D4D); // 红包红
  static const Color redPacketDark = Color(0xFFC73E3E);
  static const Color transfer = Color(0xFFFFAA4D); // 转账橙
  static const Color transferDark = Color(0xFFFA8B1F);
  static const Color unreadBadge = Color(0xFF0088CC);
  static const Color announcementBg = Color(0xFFE6F4FB); // 浅蓝横幅
  static const Color pinnedBar = Color(0xFFF0F8FD); // 置顶消息条

  // 头像色板
  static const List<Color> avatarColors = [
    Color(0xFF0088CC), Color(0xFF6ACCFF), Color(0xFF7B61FF),
    Color(0xFF00B42A), Color(0xFFFF7D00), Color(0xFFBA1A1A),
  ];

  // ===== 圆角（DESIGN.md Shapes） =====
  static const double radiusSm = 8; // 按钮/输入
  static const double radiusMd = 12; // 模态/卡片
  static const double radiusBubble = 18; // 消息气泡
  static const double radiusFull = 9999;

  /// 用于登录/注册/主操作按钮：圆角 8、白字、左侧色块 + → 箭头
  static Widget primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool fullWidth = true,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: onPrimary)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18, color: onPrimary),
          ],
        ),
      ),
    );
  }

  /// 输入框：浅灰底 + leading 圆角图标 + 圆角边框（无）
  static InputDecoration authInput({
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 15, color: textTertiary),
      prefixIcon: Icon(icon, size: 20, color: textTertiary),
      suffixIcon: suffix,
      filled: true,
      fillColor: surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primary, width: 1.2),
      ),
    );
  }

  /// 顶部品牌圆头像（内含 send 箭头）：登录/注册页面用
  static Widget brandAvatar({double size = 80}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.send_rounded, size: 36, color: Colors.white),
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: background,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

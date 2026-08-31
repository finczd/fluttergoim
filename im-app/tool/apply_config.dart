// 一键同步 APP 打包配置：读取 config/app_build.json → 写入 Android / pubspec / 运行时配置
//
// 用法：dart run tool/apply_config.dart
//
// 会同步：
//   1. appName      → android/app/src/main/AndroidManifest.xml 的 android:label
//   2. packageName  → android/app/build.gradle 的 applicationId / namespace
//   3. versionName
//      versionCode  → pubspec.yaml 的 version（Gradle 通过 flutter.versionName 读取）
//   4. apiBase
//      wsBase       → assets/config/app_config.json（App 运行时读取接口地址）
//   5. icon         → 检查文件是否存在（存在则提示用 flutter_launcher_icons 生成）

import 'dart:convert';
import 'dart:io';

const _configFile = 'config/app_build.json';
const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _gradle = 'android/app/build.gradle';
const _gradleKts = 'android/app/build.gradle.kts';
const _pubspec = 'pubspec.yaml';
const _runtimeCfg = 'assets/config/app_config.json';

void main() {
  final cfgFile = File(_configFile);
  if (!cfgFile.existsSync()) {
    stderr.writeln('✗ 找不到配置文件 $_configFile');
    exit(1);
  }

  final cfg = jsonDecode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
  final appName = (cfg['appName'] ?? '').toString();
  final pkg = (cfg['packageName'] ?? '').toString();
  final verName = (cfg['versionName'] ?? '').toString();
  final verCode = (cfg['versionCode'] ?? 1).toString();
  final apiBase = (cfg['apiBase'] ?? '').toString();
  final wsBase = (cfg['wsBase'] ?? '').toString();
  final icon = (cfg['icon'] ?? '').toString();

  stdout.writeln('读取配置 $_configFile');
  stdout.writeln('  应用名 : $appName');
  stdout.writeln('  包名   : $pkg');
  stdout.writeln('  版本   : $verName (code $verCode)');
  stdout.writeln('  接口   : $apiBase');
  stdout.writeln('  WS     : $wsBase');
  stdout.writeln('  图标   : $icon');
  stdout.writeln('');

  var changed = 0;

  // 1) 应用名 → AndroidManifest
  if (appName.isNotEmpty) {
    changed += _replaceOnce(
      _manifest,
      RegExp(r'android:label="[^"]*"'),
      'android:label="$appName"',
      '应用名 → AndroidManifest',
    );
  }

  // 2) 包名 → build.gradle（兼容 .gradle 与 .gradle.kts）
  if (pkg.isNotEmpty) {
    final gradlePath = File(_gradle).existsSync() ? _gradle : _gradleKts;
    changed += _replaceOnce(
      gradlePath,
      RegExp(r'applicationId\s*=\s*"[^"]*"'),
      'applicationId = "$pkg"',
      '包名 → applicationId',
    );
    changed += _replaceOnce(
      gradlePath,
      RegExp(r'namespace\s*=\s*"[^"]*"'),
      'namespace = "$pkg"',
      '包名 → namespace',
    );
  }

  // 3) 版本 → pubspec.yaml（Gradle 的 flutter.versionName/Code 自动跟随）
  if (verName.isNotEmpty) {
    changed += _replaceOnce(
      _pubspec,
      RegExp(r'^version:\s*\S+', multiLine: true),
      'version: $verName+$verCode',
      '版本 → pubspec',
    );
  }

  // 4) 接口地址 → 运行时配置（App 启动时读取）
  final runtime = File(_runtimeCfg);
  if (!runtime.existsSync()) {
    runtime.createSync(recursive: true);
  }
  final runtimeJson = jsonEncode({
    'apiBase': apiBase,
    'wsBase': wsBase,
  });
  if (runtime.readAsStringSync().trim() != runtimeJson) {
    runtime.writeAsStringSync('$runtimeJson\n');
    stdout.writeln('  ✓ 接口地址 → $_runtimeCfg');
    changed++;
  }

  // 5) 图标检查
  if (icon.isNotEmpty) {
    if (File(icon).existsSync()) {
      stdout.writeln('  ✓ 图标文件存在：$icon');
      stdout.writeln('    → 执行生成各密度图标：');
      stdout.writeln('      dart run flutter_launcher_icons');
    } else {
      stdout.writeln('  ⚠ 图标文件不存在：$icon');
      stdout.writeln('    把 1024x1024 PNG 放到该路径，再执行 dart run flutter_launcher_icons');
    }
  }

  stdout.writeln('');
  stdout.writeln(changed > 0
      ? '✓ 完成，共更新 $changed 处。重新打包生效：flutter build apk --release'
      : '✓ 配置已是最新，无需改动。');
}

/// 单处替换：没变则返回 0（不写文件），变了返回 1
int _replaceOnce(String path, Pattern from, String to, String label) {
  final f = File(path);
  if (!f.existsSync()) {
    stdout.writeln('  ⚠ 跳过（文件不存在）：$path');
    return 0;
  }
  final src = f.readAsStringSync();
  final out = src.replaceFirst(from, to);
  if (out == src) {
    stdout.writeln('  · 未变：$label');
    return 0;
  }
  f.writeAsStringSync(out);
  stdout.writeln('  ✓ $label');
  return 1;
}

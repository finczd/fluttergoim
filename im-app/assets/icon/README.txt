把 APP 图标源图放在本目录，命名为 **app_icon.png**（建议 1024×1024，PNG，背景不透明）。

放好后执行：

```bash
dart run flutter_launcher_icons
```

会自动生成 Android（mipmap-hdpi ~ xxxhdpi）和 iOS 各尺寸图标，覆盖 ic_launcher.png。

然后再打包：

```bash
flutter build apk --release
```

> 配置总入口：项目根目录 `config/app_build.json`（应用名 / 包名 / 版本号 / 接口地址 / 图标路径都在这改）
> 改完执行：`dart run tool/apply_config.dart`

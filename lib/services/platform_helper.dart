// 平台适配层 - 通过条件导入隔离 dart:io 依赖
// 原生平台 (Android/iOS/Windows) 使用文件系统存储图片
// Web 平台使用 base64 Data URI 存储图片
export 'platform_helper_stub.dart'
    if (dart.library.io) 'platform_helper_native.dart'
    if (dart.library.html) 'platform_helper_web.dart';

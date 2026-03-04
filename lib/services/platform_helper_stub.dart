import 'dart:typed_data';
import 'package:flutter/widgets.dart';

/// 保存图片，返回存储标识（文件路径或 data URI）
Future<String> platformSaveImage(Uint8List bytes, String fileName) =>
    throw UnsupportedError('当前平台不支持');

/// 删除图片
Future<void> platformDeleteImage(String pathOrUri) =>
    throw UnsupportedError('当前平台不支持');

/// 构建跨平台图片组件
Widget platformBuildImage(
  String source, {
  double? width,
  double? height,
  BoxFit? fit,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) =>
    throw UnsupportedError('当前平台不支持');

/// 获取数据库文件路径
Future<String> platformGetDatabasePath(String dbName) =>
    throw UnsupportedError('当前平台不支持');

/// 打开/预览图片
Future<void> platformOpenImage(BuildContext context, String source) =>
    throw UnsupportedError('当前平台不支持');

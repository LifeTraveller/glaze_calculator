import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// 将图片字节转为 base64 Data URI 存储
Future<String> platformSaveImage(Uint8List bytes, String fileName) async {
  final base64Str = base64Encode(bytes);
  // 根据文件扩展名推断 MIME 类型
  final ext = fileName.split('.').last.toLowerCase();
  final mimeType = switch (ext) {
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
  return 'data:$mimeType;base64,$base64Str';
}

/// Web 端无需删除文件，数据在数据库中随配方一起删除
Future<void> platformDeleteImage(String pathOrUri) async {
  // 空操作：base64 数据存储在数据库中，随配方删除
}

/// 解码 base64 Data URI 并构建图片组件
Widget platformBuildImage(
  String source, {
  double? width,
  double? height,
  BoxFit? fit,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  try {
    final base64Str = source.split(',').last;
    final bytes = base64Decode(base64Str);
    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  } catch (e) {
    if (errorBuilder != null) {
      return Builder(
        builder: (context) => errorBuilder(context, e, null),
      );
    }
    return SizedBox(width: width, height: height);
  }
}

/// Web 端返回数据库名称（sqflite_ffi_web 自动管理 IndexedDB 存储）
Future<String> platformGetDatabasePath(String dbName) async {
  return dbName;
}

/// 从 base64 Data URI 提取 base64 字符串
Future<String?> platformReadImageAsBase64(String pathOrUri) async {
  if (!pathOrUri.startsWith('data:')) return null;
  final parts = pathOrUri.split(',');
  if (parts.length < 2) return null;
  return parts[1];
}

/// Web 端在弹窗中预览图片
Future<void> platformOpenImage(BuildContext context, String source) async {
  final base64Str = source.split(',').last;
  final bytes = base64Decode(base64Str);

  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: const Text('图片预览'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Flexible(
            child: InteractiveViewer(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    ),
  );
}

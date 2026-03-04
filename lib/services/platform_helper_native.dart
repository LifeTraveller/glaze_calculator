import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

/// 保存图片到应用文档目录
Future<String> platformSaveImage(Uint8List bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final imagesDir = Directory(p.join(directory.path, 'recipe_images'));

  if (!await imagesDir.exists()) {
    await imagesDir.create(recursive: true);
  }

  final safeName =
      '${DateTime.now().millisecondsSinceEpoch}_${p.basename(fileName)}';
  final destPath = p.join(imagesDir.path, safeName);

  final file = File(destPath);
  await file.writeAsBytes(bytes);

  return destPath;
}

/// 删除磁盘上的图片文件
Future<void> platformDeleteImage(String pathOrUri) async {
  final file = File(pathOrUri);
  if (await file.exists()) {
    await file.delete();
  }
}

/// 通过文件路径构建图片组件
Widget platformBuildImage(
  String source, {
  double? width,
  double? height,
  BoxFit? fit,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  return Image.file(
    File(source),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}

/// 获取数据库文件路径
Future<String> platformGetDatabasePath(String dbName) async {
  final directory = await getApplicationDocumentsDirectory();
  return p.join(directory.path, dbName);
}

/// 使用系统应用打开图片
Future<void> platformOpenImage(BuildContext context, String source) async {
  await OpenFile.open(source);
}

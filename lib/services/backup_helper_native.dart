import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

/// 原生端：创建临时文件并通过分享功能导出
Future<bool> platformExportJson(String jsonString, int recipeCount) async {
  final tempDir = await Directory.systemTemp.createTemp('glaze_backup_');
  final backupFile = File(p.join(
    tempDir.path,
    'glaze_recipes_${DateTime.now().millisecondsSinceEpoch}.json',
  ));
  await backupFile.writeAsString(jsonString);

  final result = await Share.shareXFiles(
    [XFile(backupFile.path)],
    subject: '釉料配方备份',
    text: '导出了 $recipeCount 个配方',
  );

  // 清理临时文件
  await tempDir.delete(recursive: true);

  return result.status == ShareResultStatus.success;
}

/// 原生端：通过文件选择器读取 JSON
Future<String?> platformImportJson() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    dialogTitle: '选择配方备份文件',
  );

  if (result == null || result.files.isEmpty) return null;

  final filePath = result.files.single.path;
  if (filePath == null) return null;

  final file = File(filePath);
  return await file.readAsString();
}

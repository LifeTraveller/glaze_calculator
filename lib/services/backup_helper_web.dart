import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

/// Web 端：通过浏览器下载导出 JSON 文件
Future<bool> platformExportJson(String jsonString, int recipeCount) async {
  final bytes = Uint8List.fromList(utf8.encode(jsonString));
  final jsUint8Array = bytes.toJS;
  final blob = web.Blob(
    [jsUint8Array].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = 'glaze_recipes_${DateTime.now().millisecondsSinceEpoch}.json';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}

/// Web 端：通过文件选择器读取 JSON（使用 withData 获取字节）
Future<String?> platformImportJson() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );

  if (result == null || result.files.isEmpty) return null;

  final bytes = result.files.single.bytes;
  if (bytes == null) return null;

  return utf8.decode(bytes);
}

/// 导出 JSON 字符串（让用户保存）
Future<bool> platformExportJson(String jsonString, int recipeCount) =>
    throw UnsupportedError('当前平台不支持');

/// 导入 JSON 字符串（让用户选择文件）
Future<String?> platformImportJson() =>
    throw UnsupportedError('当前平台不支持');

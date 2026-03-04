import 'dart:convert';
import 'backup_helper.dart';
import 'database_service.dart';
import '../models/recipe.dart';

/// 备份服务 - 负责数据的导出和导入
class BackupService {
  final DatabaseService _dbService = DatabaseService();

  /// 导出所有配方数据
  Future<bool> exportAllRecipes() async {
    try {
      // 1. 获取所有配方
      final recipes = await _dbService.getRecipes();

      if (recipes.isEmpty) {
        return false;
      }

      // 2. 转换为 JSON 格式
      final recipesJson = recipes.map((recipe) => recipe.toMap()).toList();
      final jsonString = const JsonEncoder.withIndent('  ').convert({
        'version': '1.0',
        'export_time': DateTime.now().toIso8601String(),
        'recipes': recipesJson,
      });

      // 3. 平台适配的导出方式
      return await platformExportJson(jsonString, recipes.length);
    } catch (e) {
      return false;
    }
  }

  /// 导入配方数据
  Future<ImportResult> importRecipes() async {
    try {
      // 1. 平台适配的文件读取
      final jsonString = await platformImportJson();

      if (jsonString == null) {
        return ImportResult(success: false, message: '未选择文件');
      }

      // 2. 解析 JSON
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // 3. 验证数据格式
      if (!jsonData.containsKey('recipes') || !jsonData.containsKey('version')) {
        return ImportResult(success: false, message: '无效的备份文件格式');
      }

      final recipesList = jsonData['recipes'] as List;

      // 4. 导入配方
      int importedCount = 0;
      int skippedCount = 0;

      for (final recipeData in recipesList) {
        try {
          final recipe = Recipe.fromMap(recipeData as Map<String, dynamic>);

          // 检查配方名称是否已存在
          final existingRecipes = await _dbService.getRecipes();
          final nameExists = existingRecipes.any((r) => r.name == recipe.name);

          if (nameExists) {
            // 如果名称存在,添加后缀
            final newName = '${recipe.name} (导入)';
            final modifiedRecipe = Recipe.fromMineralFormulas(
              name: newName,
              createdAt: DateTime.now(),
              mineralAmounts: recipe.getMineralFormulaAmounts(),
              imagePaths: [], // 导入时不包含图片
            );
            await _dbService.insertRecipe(modifiedRecipe);
          } else {
            // 创建新配方(不包含图片)
            final modifiedRecipe = Recipe.fromMineralFormulas(
              name: recipe.name,
              createdAt: DateTime.now(),
              mineralAmounts: recipe.getMineralFormulaAmounts(),
              imagePaths: [],
            );
            await _dbService.insertRecipe(modifiedRecipe);
          }

          importedCount++;
        } catch (e) {
          skippedCount++;
        }
      }

      return ImportResult(
        success: true,
        message: '成功导入 $importedCount 个配方${skippedCount > 0 ? ',跳过 $skippedCount 个' : ''}',
        importedCount: importedCount,
      );
    } catch (e) {
      return ImportResult(success: false, message: '导入失败: $e');
    }
  }
}

/// 导入结果
class ImportResult {
  final bool success;
  final String message;
  final int importedCount;

  ImportResult({
    required this.success,
    required this.message,
    this.importedCount = 0,
  });
}

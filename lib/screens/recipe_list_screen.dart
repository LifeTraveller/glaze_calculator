import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../services/backup_service.dart';
import '../services/platform_helper.dart';
import '../utils/ui_helpers.dart';
import 'save_recipe_screen.dart';

/// 配方列表界面
class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final DatabaseService _dbService = DatabaseService();
  final BackupService _backupService = BackupService();
  List<Recipe> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  /// 加载配方列表
  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final recipes = await _dbService.getRecipes();
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showErrorMessage(context, '加载失败: $e');
      }
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 导出配方
  Future<void> _exportRecipes() async {
    if (_recipes.isEmpty) {
      if (mounted) {
        showErrorMessage(context, '没有配方可导出');
      }
      return;
    }

    final success = await _backupService.exportAllRecipes();
    if (mounted) {
      if (success) {
        showSuccessMessage(context, '配方导出成功');
      } else {
        showErrorMessage(context, '导出失败');
      }
    }
  }

  /// 导入配方
  Future<void> _importRecipes() async {
    final result = await _backupService.importRecipes();
    if (mounted) {
      if (result.success) {
        showSuccessMessage(context, result.message);
        _loadRecipes(); // 刷新列表
      } else {
        showErrorMessage(context, result.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('配方列表'),
        actions: [
          IconButton(
            onPressed: _importRecipes,
            icon: const Icon(Icons.upload_file),
            tooltip: '导入配方',
          ),
          IconButton(
            onPressed: _exportRecipes,
            icon: const Icon(Icons.download),
            tooltip: '导出配方',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recipes.isEmpty
              ? Center(
                  child: Text(
                    '暂无配方',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = _recipes[index];
                    return _buildRecipeItem(recipe);
                  },
                ),
    );
  }

  /// 构建配方列表项
  Widget _buildRecipeItem(Recipe recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SaveRecipeScreen(recipeId: recipe.id),
            ),
          );
          // 每次返回都刷新数据
          _loadRecipes();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 配方名称和日期
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(recipe.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 全部矿物配比
              Text(
                recipe.mineralAmounts.entries
                    .map((e) => '${e.key}: ${(e.value * 100).toStringAsFixed(0)}%')
                    .join('  '),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),

              // 照片预览
              if (recipe.imagePaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recipe.imagePaths.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: platformBuildImage(
                            recipe.imagePaths[index],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.broken_image,
                                  size: 16,
                                  color: Colors.grey[500],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

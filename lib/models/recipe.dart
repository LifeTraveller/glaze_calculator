import 'dart:convert';
import 'mineral_formula.dart';

/// 配方数据模型
class Recipe {
  final int? id;
  final String name;
  final DateTime createdAt;
  final Map<String, double> mineralAmounts; // 矿物名称 -> 百分比
  final List<String> imagePaths;

  Recipe({
    this.id,
    required this.name,
    required this.createdAt,
    required this.mineralAmounts,
    required this.imagePaths,
  });

  /// 从 MineralFormula Map 创建 Recipe
  factory Recipe.fromMineralFormulas({
    int? id,
    required String name,
    required DateTime createdAt,
    required Map<MineralFormula, double> mineralAmounts,
    required List<String> imagePaths,
  }) {
    // 将 MineralFormula 转换为矿物名称
    final Map<String, double> amounts = {};
    for (final entry in mineralAmounts.entries) {
      if (entry.value > 0.001) {
        amounts[entry.key.name] = entry.value;
      }
    }

    return Recipe(
      id: id,
      name: name,
      createdAt: createdAt,
      mineralAmounts: amounts,
      imagePaths: imagePaths,
    );
  }

  /// 转换为数据库存储的 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'mineral_amounts': jsonEncode(mineralAmounts),
      'image_paths': jsonEncode(imagePaths),
    };
  }

  /// 从数据库 Map 创建 Recipe
  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      mineralAmounts: Map<String, double>.from(
        jsonDecode(map['mineral_amounts'] as String) as Map,
      ),
      imagePaths: List<String>.from(
        jsonDecode(map['image_paths'] as String) as List,
      ),
    );
  }

  /// 获取矿物配比（转换回 MineralFormula）
  Map<MineralFormula, double> getMineralFormulaAmounts() {
    final Map<MineralFormula, double> result = {};

    for (final entry in mineralAmounts.entries) {
      // 根据名称查找对应的 MineralFormula
      final mineral = MineralFormula.all.firstWhere(
        (m) => m.name == entry.key,
        orElse: () => throw Exception('未找到矿物: ${entry.key}'),
      );
      result[mineral] = entry.value;
    }

    return result;
  }

  @override
  String toString() {
    return 'Recipe(id: $id, name: $name, createdAt: $createdAt, '
        'minerals: ${mineralAmounts.length}, images: ${imagePaths.length})';
  }
}

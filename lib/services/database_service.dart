import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'platform_helper.dart';
import '../models/recipe.dart';

/// 数据库服务 - 管理配方的本地存储
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final dbPath = await platformGetDatabasePath('glaze_calculator.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        mineral_amounts TEXT NOT NULL,
        image_paths TEXT NOT NULL
      )
    ''');
  }

  /// 插入配方
  Future<int> insertRecipe(Recipe recipe) async {
    final db = await database;
    final map = recipe.toMap();
    map.remove('id'); // 移除 id，让数据库自动生成
    return await db.insert('recipes', map);
  }

  /// 获取所有配方
  Future<List<Recipe>> getRecipes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recipes',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Recipe.fromMap(map)).toList();
  }

  /// 根据 ID 获取配方
  Future<Recipe?> getRecipeById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recipes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Recipe.fromMap(maps.first);
  }

  /// 更新配方
  Future<int> updateRecipe(Recipe recipe) async {
    final db = await database;
    return await db.update(
      'recipes',
      recipe.toMap(),
      where: 'id = ?',
      whereArgs: [recipe.id],
    );
  }

  /// 删除配方
  Future<int> deleteRecipe(int id) async {
    final db = await database;

    // 先获取配方信息，以便删除关联的照片
    final recipe = await getRecipeById(id);
    if (recipe != null) {
      // 删除关联的照片
      for (final imagePath in recipe.imagePaths) {
        await platformDeleteImage(imagePath);
      }
    }

    return await db.delete(
      'recipes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 保存图片（原生端复制到应用目录，Web 端转为 base64 Data URI）
  Future<String> saveImage(Uint8List bytes, String fileName) async {
    return await platformSaveImage(bytes, fileName);
  }

  /// 搜索配方（按名称）
  Future<List<Recipe>> searchRecipes(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recipes',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Recipe.fromMap(map)).toList();
  }

  /// 获取配方数量
  Future<int> getRecipeCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM recipes');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

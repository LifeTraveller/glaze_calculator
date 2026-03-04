import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/mineral_formula.dart';
import '../models/chemical_formula.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../services/platform_helper.dart';
import '../utils/ui_helpers.dart';
import 'recipe_edit_screen.dart';

/// 保存配方界面
class SaveRecipeScreen extends StatefulWidget {
  final Map<MineralFormula, double>? mineralAmounts; // 新建模式时传入
  final int? recipeId; // 编辑模式时传入配方ID

  const SaveRecipeScreen({
    super.key,
    this.mineralAmounts,
    this.recipeId,
  });

  @override
  State<SaveRecipeScreen> createState() => _SaveRecipeScreenState();
}

class _SaveRecipeScreenState extends State<SaveRecipeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final List<Uint8List> _selectedImageBytes = []; // 缓存新选图片的字节
  final List<String> _existingImagePaths = [];
  final ImagePicker _picker = ImagePicker();

  Map<ChemicalFormula, double> _molarAmounts = {};
  Map<MineralFormula, double> _mineralAmounts = {};

  bool _isLoading = true;
  Recipe? _existingRecipe;

  bool get _isEditMode => widget.recipeId != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 加载数据
  Future<void> _loadData() async {
    if (_isEditMode) {
      // 编辑模式：从数据库加载配方
      final dbService = DatabaseService();
      final recipe = await dbService.getRecipeById(widget.recipeId!);
      if (recipe != null) {
        _existingRecipe = recipe;
        _nameController.text = recipe.name;
        _existingImagePaths.addAll(recipe.imagePaths);
        _mineralAmounts = recipe.getMineralFormulaAmounts();
      }
    } else {
      // 新建模式：使用传入的矿物配比
      _mineralAmounts = widget.mineralAmounts ?? {};
    }

    _molarAmounts = _calculateSegerFormula();

    setState(() {
      _isLoading = false;
    });
  }

  /// 从矿物配比计算赛格釉式
  Map<ChemicalFormula, double> _calculateSegerFormula() {
    final Map<MineralFormula, double> mineralMoles = {};
    for (final entry in _mineralAmounts.entries) {
      final mineral = entry.key;
      final massPercent = entry.value;
      if (massPercent > 0) {
        mineralMoles[mineral] = massPercent / mineral.molarMass;
      }
    }

    final Map<ChemicalFormula, double> formulaMoles = {};
    for (final entry in mineralMoles.entries) {
      final mineral = entry.key;
      final mineralMole = entry.value;

      for (final formulaEntry in mineral.firedComposition.entries) {
        final formula = formulaEntry.key;
        final ratio = formulaEntry.value;
        formulaMoles[formula] = (formulaMoles[formula] ?? 0.0) + (mineralMole * ratio);
      }
    }

    double roSum = 0.0;
    for (final entry in formulaMoles.entries) {
      if (entry.key.isRO) {
        roSum += entry.value;
      }
    }

    if (roSum > 0) {
      for (final formula in formulaMoles.keys) {
        formulaMoles[formula] = formulaMoles[formula]! / roSum;
      }
    }

    return formulaMoles;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _selectedImages.add(photo);
          _selectedImageBytes.add(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorMessage(context, '拍照失败: $e');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        for (final image in images) {
          final bytes = await image.readAsBytes();
          _selectedImages.add(image);
          _selectedImageBytes.add(bytes);
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        showErrorMessage(context, '选择照片失败: $e');
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _selectedImageBytes.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImagePaths.removeAt(index);
    });
  }

  Future<void> _openImage(String path) async {
    try {
      if (mounted) {
        await platformOpenImage(context, path);
      }
    } catch (e) {
      if (mounted) {
        showErrorMessage(context, '打开图片失败: $e');
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 修改矿物配比
  Future<void> _editMineralAmounts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeEditScreen(
          initialMineralAmounts: _mineralAmounts,
          recipeId: _existingRecipe?.id,
        ),
      ),
    );

    // 每次返回都从数据库重新加载数据
    if (_existingRecipe?.id != null) {
      final dbService = DatabaseService();
      final recipe = await dbService.getRecipeById(_existingRecipe!.id!);
      if (recipe != null && mounted) {
        setState(() {
          _mineralAmounts = recipe.getMineralFormulaAmounts();
          _molarAmounts = _calculateSegerFormula();
        });
      }
    }
  }

  /// 删除配方
  Future<void> _deleteRecipe() async {
    final confirm = await showDeleteConfirmDialog(
      context,
      '配方 "${_existingRecipe?.name}"',
    );

    if (confirm == true && _existingRecipe?.id != null) {
      try {
        final dbService = DatabaseService();
        await dbService.deleteRecipe(_existingRecipe!.id!);
        if (mounted) {
          showSuccessMessage(context, '配方 "${_existingRecipe!.name}" 已删除');
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          showErrorMessage(context, '删除失败: $e');
        }
      }
    }
  }

  Future<void> _saveRecipe() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showErrorMessage(context, '请输入配方名称');
      return;
    }

    try {
      final dbService = DatabaseService();

      final List<String> savedImagePaths = [];
      savedImagePaths.addAll(_existingImagePaths);

      for (final image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final savedPath = await dbService.saveImage(bytes, image.name);
        savedImagePaths.add(savedPath);
      }

      final recipe = Recipe.fromMineralFormulas(
        id: _isEditMode ? _existingRecipe!.id : null,
        name: name,
        createdAt: _isEditMode ? _existingRecipe!.createdAt : DateTime.now(),
        mineralAmounts: _mineralAmounts,
        imagePaths: savedImagePaths,
      );

      if (_isEditMode) {
        await dbService.updateRecipe(recipe);
      } else {
        await dbService.insertRecipe(recipe);
      }

      if (mounted) {
        showSuccessMessage(context, '配方 "$name" 已保存');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showErrorMessage(context, '保存失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEditMode ? '编辑配方' : '保存配方')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '编辑配方' : '保存配方'),
        actions: [
          if (_isEditMode)
            IconButton(
              onPressed: _deleteRecipe,
              icon: Icon(
                Icons.delete_outline,
                color: Colors.red[400],
              ),
              tooltip: '删除',
            ),
          IconButton(
            onPressed: _saveRecipe,
            icon: const Icon(Icons.save),
            tooltip: '保存',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 配方名称
            const Text(
              '配方名称',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '请输入配方名称',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // 照片区域
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '配方照片',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.add_photo_alternate, size: 18),
                  label: const Text('添加照片'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 照片列表
            if (_existingImagePaths.isEmpty && _selectedImages.isEmpty)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('暂无照片', style: TextStyle(color: Colors.grey[500])),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImagePaths.length + _selectedImages.length,
                  itemBuilder: (context, index) {
                    final isExisting = index < _existingImagePaths.length;
                    final newIndex = index - _existingImagePaths.length;

                    // 构建图片组件：已保存的用 platformBuildImage，新选的用 Image.memory
                    Widget imageWidget;
                    if (isExisting) {
                      imageWidget = platformBuildImage(
                        _existingImagePaths[index],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      );
                    } else {
                      imageWidget = Image.memory(
                        _selectedImageBytes[newIndex],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: isExisting
                                ? () => _openImage(_existingImagePaths[index])
                                : null,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageWidget,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                if (isExisting) {
                                  _removeExistingImage(index);
                                } else {
                                  _removeImage(newIndex);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),

            // 矿物配比
            if (_mineralAmounts.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '矿物配比',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _editMineralAmounts,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('修改'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _mineralAmounts.entries
                      .where((e) => e.value > 0.001)
                      .map((entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(entry.key.name, style: const TextStyle(fontSize: 14))),
                                Text(
                                  '${(entry.value * 100).toStringAsFixed(2)}%',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 赛格釉式
            if (_molarAmounts.isNotEmpty) ...[
              const Text(
                '赛格釉式',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildSegerFormulaGroups(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSegerFormulaGroups() {
    final groups = <Widget>[];

    for (final entry in ChemicalFormula.categoryMap.entries) {
      final categoryName = entry.key;
      final categoryList = entry.value;

      final categoryFormulas = _molarAmounts.entries
          .where((e) => categoryList.contains(e.key) && e.value > 0.001)
          .toList();

      if (categoryFormulas.isEmpty) continue;

      groups.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            categoryName,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
        ),
      );

      for (final formulaEntry in categoryFormulas) {
        groups.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formulaEntry.key.name, style: const TextStyle(fontSize: 14)),
                Text(
                  formulaEntry.value.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      }
    }

    return groups;
  }
}

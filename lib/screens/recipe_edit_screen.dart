import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chemical_formula.dart';
import '../models/mineral_formula.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../utils/ui_helpers.dart';
import 'save_recipe_screen.dart';

/// 验证结果类 - 用于矿物化学式匹配验证
class _ValidationResult {
  final bool isValid;
  final List<ChemicalFormula> missingFormulas;  // 缺失的化学式（赛格釉式需要，但矿物无法提供）
  final Map<MineralFormula, List<ChemicalFormula>> impurityFormulas;  // 杂质：多化学式矿物引入的额外成分

  _ValidationResult({
    required this.isValid,
    this.missingFormulas = const [],
    this.impurityFormulas = const {},
  });
}

/// 配方编辑页面 - 包含赛格釉式和矿物配比两个标签页
class RecipeEditScreen extends StatefulWidget {
  final Map<MineralFormula, double>? initialMineralAmounts; // 编辑模式时传入初始配比
  final int? recipeId; // 编辑模式时传入配方ID，用于更新数据库

  const RecipeEditScreen({
    super.key,
    this.initialMineralAmounts,
    this.recipeId,
  });

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 矿物配比数据
  final Map<MineralFormula, double> _mineralAmounts = {};
  final Set<MineralFormula> _lockedMinerals = {};
  final Set<MineralFormula> _selectedMinerals = {};

  // 赛格釉式数据
  final Map<ChemicalFormula, double> _molarAmounts = {};
  final Set<ChemicalFormula> _lockedFormulas = {};
  final Set<ChemicalFormula> _selectedFormulas = {};

  bool get _isEditMode => widget.initialMineralAmounts != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 编辑模式：加载初始配比
    if (widget.initialMineralAmounts != null) {
      _mineralAmounts.addAll(widget.initialMineralAmounts!);
      _selectedMinerals.addAll(widget.initialMineralAmounts!.keys);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 将矿物配比转换为赛格釉式
  void _convertMaterialsToSeger() {
    if (_selectedMinerals.isEmpty) {
      showInfoDialog(context, '请先添加矿物式');
      return;
    }

    // 直接执行转换
    _performConversion();
  }

  /// 执行转换计算
  void _performConversion() {
    // 步骤1: 计算每个矿物的摩尔量（质量 / 摩尔质量）
    final Map<MineralFormula, double> mineralMoles = {};
    for (final entry in _mineralAmounts.entries) {
      final mineral = entry.key;
      final massPercent = entry.value; // 质量百分比 (0-1)
      if (massPercent > 0) {
        mineralMoles[mineral] = massPercent / mineral.molarMass;
      }
    }

    // 步骤2: 汇总所有化学式的摩尔量（使用烧成后的组成）
    final Map<ChemicalFormula, double> formulaMoles = {};
    for (final entry in mineralMoles.entries) {
      final mineral = entry.key;
      final mineralMole = entry.value;

      // 遍历矿物烧成后的化学式组成
      for (final formulaEntry in mineral.firedComposition.entries) {
        final formula = formulaEntry.key;
        final ratio = formulaEntry.value; // 化学式在矿物中的摩尔比

        formulaMoles[formula] = (formulaMoles[formula] ?? 0.0) + (mineralMole * ratio);
      }
    }

    // 步骤3: 将RO类氧化物归一化为总和=1（赛格釉式标准）
    double roSum = 0.0;
    for (final entry in formulaMoles.entries) {
      if (entry.key.isRO) {
        roSum += entry.value;
      }
    }

    if (roSum > 0) {
      // 归一化：所有化学式摩尔量除以RO总和
      for (final formula in formulaMoles.keys) {
        formulaMoles[formula] = formulaMoles[formula]! / roSum;
      }
    }

    // 步骤4: 更新赛格釉式数据
    setState(() {
      _selectedFormulas.clear();
      _molarAmounts.clear();
      _lockedFormulas.clear();

      for (final entry in formulaMoles.entries) {
        if (entry.value > 0.001) {  // 过滤掉非常小的值
          _selectedFormulas.add(entry.key);
          _molarAmounts[entry.key] = entry.value;
        }
      }

      // 切换到赛格釉式标签页
      _tabController.animateTo(1);
    });
  }

  /// 将赛格釉式转换为矿物配比
  void _convertSegerToMaterials() {
    // 检查是否在矿物配比中选择了矿物
    if (_selectedMinerals.isEmpty) {
      showInfoDialog(context, '请先在"矿物配比"标签页选择要使用的矿物式');
      return;
    }

    // 检查是否有化学式数据
    if (_selectedFormulas.isEmpty || _molarAmounts.isEmpty) {
      showInfoDialog(context, '请先添加化学式');
      return;
    }

    // 检查矿物是否能提供所需的化学式
    final validationResult = _validateMineralFormulaMatch();
    // 如果有任何警告信息（缺失化学式或杂质），显示对话框
    if (validationResult.missingFormulas.isNotEmpty ||
        validationResult.impurityFormulas.isNotEmpty) {
      _showValidationDialog(validationResult);
      return;
    }

    // 直接执行计算
    _performReverseConversion();
  }

  /// 验证选择的矿物能否提供所需的化学式
  _ValidationResult _validateMineralFormulaMatch() {
    final missingFormulas = <ChemicalFormula>[];
    final impurityFormulas = <MineralFormula, List<ChemicalFormula>>{};

    // 收集赛格釉式中需要的化学式（摩尔量 > 0.001 的）
    final Set<ChemicalFormula> requiredFormulas = {};
    for (final formula in _selectedFormulas) {
      final amount = _molarAmounts[formula] ?? 0.0;
      if (amount >= 0.001) {
        requiredFormulas.add(formula);
      }
    }

    // 收集所有矿物烧成后能提供的化学式
    final Set<ChemicalFormula> availableFormulas = {};
    for (final mineral in _selectedMinerals) {
      for (final formula in mineral.firedComposition.keys) {
        availableFormulas.add(formula);
      }
    }

    // 步骤1: 检查赛格釉式需要的化学式，矿物是否能提供
    for (final formula in requiredFormulas) {
      if (!availableFormulas.contains(formula)) {
        missingFormulas.add(formula);
      }
    }

    // 步骤2: 检查所有矿物的杂质（矿物提供但釉式未选择的化学式）
    for (final mineral in _selectedMinerals) {
      final firedComp = mineral.firedComposition;

      // 检查该矿物烧成后的每个化学式
      final impurities = <ChemicalFormula>[];
      for (final formula in firedComp.keys) {
        // 如果该化学式不在赛格釉式需要的列表中，标记为杂质
        if (!requiredFormulas.contains(formula)) {
          impurities.add(formula);
        }
      }

      // 如果有杂质，添加到结果中
      if (impurities.isNotEmpty) {
        impurityFormulas[mineral] = impurities;
      }
    }

    return _ValidationResult(
      isValid: missingFormulas.isEmpty,
      missingFormulas: missingFormulas,
      impurityFormulas: impurityFormulas,
    );
  }

  /// 显示验证结果对话框
  void _showValidationDialog(_ValidationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 缺失的化学式
                if (result.missingFormulas.isNotEmpty) ...[
                  const Text(
                    '矿物式缺少以下化学式:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...result.missingFormulas.map((formula) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      formula.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  )),
                ],
                // 杂质化学式（按矿物分组显示）
                if (result.impurityFormulas.isNotEmpty) ...[
                  if (result.missingFormulas.isNotEmpty) const Divider(height: 24),
                  const Text(
                    '以下矿物式存在杂质:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...result.impurityFormulas.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${entry.key.name}: ${entry.value.map((f) => f.name).join('、')}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 执行反向转换计算(赛格釉式 → 矿物配比)
  void _performReverseConversion() {
    // 构建问题: 找到矿物百分比 x,使得 Ax ≈ b
    // A: 矿物提供的化学式系数矩阵
    // x: 矿物质量百分比(未知)
    // b: 目标化学式摩尔量

    final minerals = _selectedMinerals.toList();
    final formulas = _selectedFormulas.toList();

    final int m = minerals.length;  // 矿物数量
    final int n = formulas.length;  // 化学式数量

    if (m == 0 || n == 0) return;

    // 构建目标向量 b (目标化学式摩尔量)
    final List<double> b = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      b[i] = _molarAmounts[formulas[i]] ?? 0.0;
    }

    // 构建系数矩阵 A (每个矿物提供的化学式摩尔量)
    // A[i][j] = 矿物j提供的化学式i的摩尔量(假设矿物质量百分比为1)
    final List<List<double>> A = List.generate(n, (_) => List<double>.filled(m, 0.0));

    for (int j = 0; j < m; j++) {
      final mineral = minerals[j];
      final mineralMolePerUnitMass = 1.0 / mineral.molarMass;  // 单位质量的摩尔量

      for (int i = 0; i < n; i++) {
        final formula = formulas[i];
        // 查找矿物烧成后是否包含该化学式
        final ratio = mineral.firedComposition[formula];
        if (ratio != null) {
          A[i][j] = mineralMolePerUnitMass * ratio;
        }
      }
    }

    // 使用最小二乘法求解
    final solution = _solveLeastSquares(A, b, m, n);

    if (solution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('计算失败:无法求解')),
      );
      return;
    }

    // 归一化解(使总和 = 1)
    double sum = solution.fold(0.0, (a, b) => a + b);
    if (sum < 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('计算失败:无有效解')),
      );
      return;
    }

    final List<double> normalizedSolution = solution.map((v) => v / sum).toList();

    // 计算拟合误差
    final List<double> predicted = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < m; j++) {
        predicted[i] += A[i][j] * normalizedSolution[j];
      }
    }

    // 归一化预测值(按RO归一化)
    double roSum = 0.0;
    for (int i = 0; i < n; i++) {
      if (formulas[i].isRO) {
        roSum += predicted[i];
      }
    }
    if (roSum > 0) {
      for (int i = 0; i < n; i++) {
        predicted[i] /= roSum;
      }
    }

    // 计算每个氧化物的误差详情
    final List<Map<String, dynamic>> errorDetails = [];
    double totalError = 0.0;
    for (int i = 0; i < n; i++) {
      final error = (predicted[i] - b[i]).abs();
      totalError += error;
      errorDetails.add({
        'formula': formulas[i],
        'target': b[i],
        'predicted': predicted[i],
        'error': error,
      });
    }
    final avgError = totalError / n;

    // 如果误差为0（或接近0），直接应用结果
    if (avgError < 0.0001) {
      setState(() {
        _mineralAmounts.clear();
        for (int i = 0; i < minerals.length; i++) {
          _mineralAmounts[minerals[i]] = normalizedSolution[i];
        }
        _lockedMinerals.clear();
        // 切换到矿物配比标签页
        _tabController.animateTo(0);
      });
      return;
    }

    // 显示结果对话框
    _showConversionResultDialog(
      minerals,
      normalizedSolution,
      avgError,
      errorDetails,
    );
  }

  /// 最小二乘求解器: 求解 min ||Ax - b||²
  /// A: n×m 矩阵, b: n维向量, 返回: m维解向量
  List<double>? _solveLeastSquares(List<List<double>> A, List<double> b, int m, int n) {
    // 使用正规方程: A^T A x = A^T b
    // 计算 A^T A (m×m 矩阵)
    final List<List<double>> ata = List.generate(m, (_) => List<double>.filled(m, 0.0));
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < m; j++) {
        double sum = 0.0;
        for (int k = 0; k < n; k++) {
          sum += A[k][i] * A[k][j];
        }
        ata[i][j] = sum;
      }
    }

    // 计算 A^T b (m维向量)
    final List<double> atb = List<double>.filled(m, 0.0);
    for (int i = 0; i < m; i++) {
      double sum = 0.0;
      for (int k = 0; k < n; k++) {
        sum += A[k][i] * b[k];
      }
      atb[i] = sum;
    }

    // 使用高斯消元法求解 ata x = atb
    final solution = _gaussianElimination(ata, atb, m);

    if (solution == null) return null;

    // 应用非负约束(矿物百分比 ≥ 0)
    for (int i = 0; i < m; i++) {
      if (solution[i] < 0) {
        solution[i] = 0.0;
      }
    }

    return solution;
  }

  /// 高斯消元法求解线性方程组 Ax = b
  List<double>? _gaussianElimination(List<List<double>> A, List<double> b, int n) {
    // 创建增广矩阵
    final List<List<double>> augmented = List.generate(
      n,
      (i) => [...A[i], b[i]],
    );

    // 前向消元
    for (int k = 0; k < n; k++) {
      // 寻找主元
      int maxRow = k;
      double maxVal = augmented[k][k].abs();
      for (int i = k + 1; i < n; i++) {
        if (augmented[i][k].abs() > maxVal) {
          maxVal = augmented[i][k].abs();
          maxRow = i;
        }
      }

      // 交换行
      if (maxRow != k) {
        final temp = augmented[k];
        augmented[k] = augmented[maxRow];
        augmented[maxRow] = temp;
      }

      // 检查奇异性
      if (augmented[k][k].abs() < 1e-10) {
        continue;  // 跳过近似为0的主元
      }

      // 消元
      for (int i = k + 1; i < n; i++) {
        final factor = augmented[i][k] / augmented[k][k];
        for (int j = k; j <= n; j++) {
          augmented[i][j] -= factor * augmented[k][j];
        }
      }
    }

    // 回代求解
    final List<double> x = List<double>.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      if (augmented[i][i].abs() < 1e-10) {
        x[i] = 0.0;  // 不确定的变量设为0
        continue;
      }

      double sum = augmented[i][n];
      for (int j = i + 1; j < n; j++) {
        sum -= augmented[i][j] * x[j];
      }
      x[i] = sum / augmented[i][i];
    }

    return x;
  }

  /// 显示转换结果对话框
  void _showConversionResultDialog(
    List<MineralFormula> minerals,
    List<double> percentages,
    double avgError,
    List<Map<String, dynamic>> errorDetails,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('计算结果'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 矿物配比（包含釉式）
                const Text('矿物配比:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...List.generate(minerals.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${minerals[i].name}: ${(percentages[i] * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          minerals[i].formulaString,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const Divider(height: 24),

                // 误差详情
                const Text('误差详情:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // 表头
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        '氧化物',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '目标值',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '预测值',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '误差',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 8),

                // 误差数据行
                ...errorDetails.map((detail) {
                  final formula = detail['formula'] as ChemicalFormula;
                  final target = detail['target'] as double;
                  final predicted = detail['predicted'] as double;
                  final error = detail['error'] as double;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            formula.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            target.toStringAsFixed(3),
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            predicted.toStringAsFixed(3),
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            error.toStringAsFixed(3),
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),
                Text(
                  '平均误差: ${(avgError * 100).toStringAsFixed(2)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 应用到矿物配比
              setState(() {
                _mineralAmounts.clear();
                for (int i = 0; i < minerals.length; i++) {
                  _mineralAmounts[minerals[i]] = percentages[i];
                }
                _lockedMinerals.clear();
                // 切换到矿物配比标签页
                _tabController.animateTo(0);
              });
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }

  /// 归一化矿物配比（使总和为1.0）
  Map<MineralFormula, double> _getNormalizedMineralAmounts() {
    // 计算总和
    double totalAmount = 0.0;
    for (final amount in _mineralAmounts.values) {
      totalAmount += amount;
    }

    // 如果总和为0，返回原值
    if (totalAmount == 0.0) {
      return Map.from(_mineralAmounts);
    }

    // 归一化：每个值除以总和
    final normalized = <MineralFormula, double>{};
    for (final entry in _mineralAmounts.entries) {
      normalized[entry.key] = entry.value / totalAmount;
    }
    return normalized;
  }

  /// 跳转到保存配方界面
  Future<void> _navigateToSaveScreen() async {
    // 检查矿物配比是否有设置且有效
    final hasValidAmount = _mineralAmounts.isNotEmpty &&
        _mineralAmounts.values.any((amount) => amount > 0);

    if (!hasValidAmount) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('请先设置矿物配比'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    // 归一化矿物配比
    final normalizedAmounts = _getNormalizedMineralAmounts();

    // 编辑模式：更新数据库后返回
    if (_isEditMode) {
      try {
        if (widget.recipeId != null) {
          final dbService = DatabaseService();
          final recipe = await dbService.getRecipeById(widget.recipeId!);
          if (recipe != null) {
            final updatedRecipe = Recipe.fromMineralFormulas(
              id: recipe.id,
              name: recipe.name,
              createdAt: recipe.createdAt,
              mineralAmounts: normalizedAmounts,
              imagePaths: recipe.imagePaths,
            );
            await dbService.updateRecipe(updatedRecipe);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('配方已保存')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e')),
          );
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    // 新建模式：保存到数据库，显示成功提示，然后跳转到保存界面
    try {
      final dbService = DatabaseService();
      final recipe = Recipe.fromMineralFormulas(
        name: '未定义名称',
        createdAt: DateTime.now(),
        mineralAmounts: normalizedAmounts,
        imagePaths: [],
      );
      final recipeId = await dbService.insertRecipe(recipe);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配方已保存')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SaveRecipeScreen(recipeId: recipeId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('配方编辑'),
        actions: [
          IconButton(
            onPressed: _navigateToSaveScreen,
            icon: const Icon(Icons.save),
            tooltip: '保存配方',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: '矿物配比'),
            Tab(icon: Icon(Icons.science), text: '赛格釉式'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MineralRatioTab(
            mineralAmounts: _mineralAmounts,
            lockedMinerals: _lockedMinerals,
            selectedMinerals: _selectedMinerals,
            onConvertToSeger: _convertMaterialsToSeger,
            onDataChanged: () => setState(() {}),
          ),
          SegerFormulaTab(
            molarAmounts: _molarAmounts,
            lockedFormulas: _lockedFormulas,
            selectedFormulas: _selectedFormulas,
            onConvertToMaterials: _convertSegerToMaterials,
            onDataChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

/// B标签页：矿物配比
class MineralRatioTab extends StatefulWidget {
  final Map<MineralFormula, double> mineralAmounts;
  final Set<MineralFormula> lockedMinerals;
  final Set<MineralFormula> selectedMinerals;
  final VoidCallback onConvertToSeger;
  final VoidCallback onDataChanged;

  const MineralRatioTab({
    super.key,
    required this.mineralAmounts,
    required this.lockedMinerals,
    required this.selectedMinerals,
    required this.onConvertToSeger,
    required this.onDataChanged,
  });

  @override
  State<MineralRatioTab> createState() => _MineralRatioTabState();
}

class _MineralRatioTabState extends State<MineralRatioTab>
    with AutomaticKeepAliveClientMixin, InputControllerManager<MineralFormula> {
  @override
  bool get wantKeepAlive => true; // 保持标签页状态

  @override
  void didUpdateWidget(MineralRatioTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 清理不再存在的矿物
    cleanupRemovedItems(widget.selectedMinerals);
    // 更新所有矿物的controller文本
    for (final material in widget.selectedMinerals) {
      updateControllerText(material, _getMineralText);
    }
  }

  @override
  void dispose() {
    disposeAllResources();
    super.dispose();
  }

  /// 获取矿物的文本表示
  String _getMineralText(MineralFormula mineral) {
    final amount = widget.mineralAmounts[mineral] ?? 0.0;
    return amount > 0 ? (amount * 100).toStringAsFixed(2) : '';
  }

  /// 设置单个矿物的百分比（不再自动调整其他矿物）
  void _setPercentage(MineralFormula targetMaterial, double newValue) {
    if (widget.selectedMinerals.isEmpty) return;

    // 直接设置目标矿物的新值，不限制最大值
    widget.mineralAmounts[targetMaterial] = newValue.clamp(0.0, double.infinity);
    widget.onDataChanged();
  }

  /// 构建单个矿物项
  Widget _buildMineralCard(MineralFormula mineral) {
    return Container(
      key: ValueKey(mineral),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 矿物名称和化学式
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mineral.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                mineral.formulaString,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // 百分比输入框
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: getOrCreateController(mineral, _getMineralText),
                  focusNode: getOrCreateFocusNode(mineral),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    DecimalInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                    hintText: '质量',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (value) {
                    final newValue = (double.tryParse(value) ?? 0.0) / 100;
                    _setPercentage(mineral, newValue);
                  },
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 删除按钮
          InkWell(
            onTap: () async {
              final confirm = await showDeleteConfirmDialog(context, mineral.name);
              if (confirm == true) {
                widget.selectedMinerals.remove(mineral);
                widget.mineralAmounts.remove(mineral);
                widget.lockedMinerals.remove(mineral);
                widget.onDataChanged();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red[400],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以保持状态
    return Column(
      children: [
        // 按钮行：添加矿物 + 转换为赛格釉式
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _showAddMineralDialog,
                icon: const Icon(Icons.add),
                label: const Text('添加矿物式'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: widget.selectedMinerals.isEmpty
                    ? null
                    : widget.onConvertToSeger,
                icon: const Icon(Icons.transform),
                label: const Text('转换为赛格釉式'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // 已选择的矿物列表
        Expanded(
          child: widget.selectedMinerals.isEmpty
              ? const Center(
                  child: Text(
                    '点击"添加矿物式"开始配制釉料',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: widget.selectedMinerals.map((mineral) {
                    return _buildMineralCard(mineral);
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // 显示添加矿物对话框
  void _showAddMineralDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: MineralFormula.all.map((mineral) {
                final isSelected = widget.selectedMinerals.contains(mineral);
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  title: Text(mineral.name),
                  subtitle: Text(mineral.formulaString),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    if (!isSelected) {
                      widget.selectedMinerals.add(mineral);
                      // 新添加的矿物默认值为 0
                      widget.mineralAmounts[mineral] = 0.0;
                      widget.onDataChanged();
                    }
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

/// 赛格釉式输入模式
enum SegerInputMode {
  molar,  // 摩尔量模式：输入摩尔量，显示质量占比
  mass,   // 质量模式：输入质量，计算摩尔量
}

/// A标签页：赛格釉式
class SegerFormulaTab extends StatefulWidget {
  final Map<ChemicalFormula, double> molarAmounts;
  final Set<ChemicalFormula> lockedFormulas;
  final Set<ChemicalFormula> selectedFormulas;
  final VoidCallback onConvertToMaterials;
  final VoidCallback onDataChanged;

  const SegerFormulaTab({
    super.key,
    required this.molarAmounts,
    required this.lockedFormulas,
    required this.selectedFormulas,
    required this.onConvertToMaterials,
    required this.onDataChanged,
  });

  @override
  State<SegerFormulaTab> createState() => _SegerFormulaTabState();
}

/// 自定义 RO 输入格式化器 - 限制格式和数值范围
class _ROInputFormatter extends TextInputFormatter {
  final double maxValue;

  _ROInputFormatter({this.maxValue = 1.0});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 空字符串允许
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // 尝试解析数值
    final value = double.tryParse(newValue.text);

    // 无法解析，保留旧值
    if (value == null) {
      return oldValue;
    }

    // 超出范围[0, maxValue]，保留旧值
    if (value > maxValue || value < 0) {
      return oldValue;
    }

    // 限制格式：0.00-1.00，最多两位小数
    final pattern = RegExp(r'^(0(\.\d{0,2})?|1(\.0{0,2})?|0?\.\d{0,2})$');
    if (!pattern.hasMatch(newValue.text)) {
      return oldValue;
    }

    return newValue;
  }
}


class _SegerFormulaTabState extends State<SegerFormulaTab>
    with AutomaticKeepAliveClientMixin, InputControllerManager<ChemicalFormula> {
  @override
  bool get wantKeepAlive => true; // 保持标签页状态

  // 输入模式：摩尔量或质量
  SegerInputMode _inputMode = SegerInputMode.molar;

  // 质量模式下存储用户输入的质量值
  final Map<ChemicalFormula, double> _massAmounts = {};

  @override
  void didUpdateWidget(SegerFormulaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 清理不再存在的化学式
    cleanupRemovedItems(widget.selectedFormulas);
    // 清理质量数据中不再存在的化学式
    _massAmounts.removeWhere((key, _) => !widget.selectedFormulas.contains(key));
    // 更新所有化学式的controller文本
    for (final formula in widget.selectedFormulas) {
      updateControllerText(formula, _getFormulaText);
    }
  }

  @override
  void dispose() {
    disposeAllResources();
    super.dispose();
  }

  /// 切换输入模式
  void _switchInputMode(SegerInputMode mode) {
    if (_inputMode == mode) return;

    setState(() {
      if (mode == SegerInputMode.mass) {
        // 从摩尔量模式切换到质量模式：根据摩尔量计算质量
        _massAmounts.clear();
        for (final formula in widget.selectedFormulas) {
          final molarAmount = widget.molarAmounts[formula] ?? 0.0;
          _massAmounts[formula] = molarAmount * formula.molarMass;
        }
      }
      // 从质量模式切换到摩尔量模式时，摩尔量已经在输入时更新了
      _inputMode = mode;

      // 强制更新所有输入框文本（忽略焦点状态）
      for (final formula in widget.selectedFormulas) {
        forceUpdateControllerText(formula, _getFormulaText);
      }
    });
  }

  /// 获取化学式的文本表示（根据当前模式）
  String _getFormulaText(ChemicalFormula formula) {
    if (_inputMode == SegerInputMode.molar) {
      final molarAmount = widget.molarAmounts[formula] ?? 0.0;
      return molarAmount > 0 ? molarAmount.toStringAsFixed(2) : '';
    } else {
      final massAmount = _massAmounts[formula] ?? 0.0;
      return massAmount > 0 ? massAmount.toStringAsFixed(2) : '';
    }
  }

  /// 计算所有化学式的总质量
  double _calculateTotalMass() {
    double totalMass = 0.0;
    for (final entry in widget.molarAmounts.entries) {
      final formula = entry.key;
      final molarAmount = entry.value;
      totalMass += molarAmount * formula.molarMass;
    }
    return totalMass;
  }

  /// 计算单个化学式的质量占比
  double _calculateMassPercentage(ChemicalFormula formula) {
    final totalMass = _calculateTotalMass();
    if (totalMass == 0.0) return 0.0;

    final molarAmount = widget.molarAmounts[formula] ?? 0.0;
    final mass = molarAmount * formula.molarMass;
    return (mass / totalMass) * 100; // 返回百分比
  }

  /// 质量模式：根据输入的质量计算摩尔量并更新
  void _updateMolarFromMass(ChemicalFormula formula, double mass) {
    _massAmounts[formula] = mass;
    // 计算摩尔量 = 质量 / 摩尔质量
    final molarAmount = mass / formula.molarMass;
    widget.molarAmounts[formula] = molarAmount;
    widget.onDataChanged();
  }

  /// 质量模式：将质量转换为赛格釉式（RO归一化）并计算矿物配比
  void _convertMassToSegerAndMaterials() {
    // 步骤1：计算RO类的摩尔量总和
    double roSum = 0.0;
    for (final formula in widget.selectedFormulas) {
      if (formula.isRO) {
        roSum += widget.molarAmounts[formula] ?? 0.0;
      }
    }

    if (roSum <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个RO类氧化物')),
      );
      return;
    }

    // 步骤2：将所有摩尔量按RO总和归一化（内部计算用，不改变显示）
    for (final formula in widget.selectedFormulas) {
      final currentMolar = widget.molarAmounts[formula] ?? 0.0;
      widget.molarAmounts[formula] = currentMolar / roSum;
    }

    widget.onDataChanged();

    // 步骤3：直接调用转换到矿物配比（保持质量模式不变）
    widget.onConvertToMaterials();
  }

  /// 按分类构建化学式组
  List<Widget> _buildCategoryGroups() {
    final groups = <Widget>[];

    // 按分类分组化学式
    for (final entry in ChemicalFormula.categoryMap.entries) {
      final categoryName = entry.key;
      final categoryList = entry.value;

      final categoryFormulas = widget.selectedFormulas
          .where((f) => categoryList.contains(f))
          .toList();

      if (categoryFormulas.isEmpty) continue;

      // 分类标题
      groups.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            categoryName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
      );

      // 该分类下的化学式
      for (final formula in categoryFormulas) {
        groups.add(_buildFormulaCard(formula));
      }
    }

    return groups;
  }

  /// 调整单个 RO 的值，同时调整其他未锁定的 RO
  void _adjustRO(ChemicalFormula targetFormula, double newValue) {
    final roFormulas = widget.selectedFormulas.where((f) => f.isRO).toList();
    if (roFormulas.isEmpty) return;

    // 设置目标 RO 的新值
    widget.molarAmounts[targetFormula] = newValue.clamp(0.0, 1.0);

    // 计算所有锁定的 RO（包括当前正在调整的）的总和
    double lockedSum = 0.0;
    final unlockedFormulas = <ChemicalFormula>[];

    for (final formula in roFormulas) {
      if (widget.lockedFormulas.contains(formula) || formula == targetFormula) {
        lockedSum += widget.molarAmounts[formula] ?? 0.0;
      } else {
        unlockedFormulas.add(formula);
      }
    }

    // 如果锁定的总和已经超过 1，需要截断目标值
    if (lockedSum > 1.0) {
      final excess = lockedSum - 1.0;
      widget.molarAmounts[targetFormula] = (newValue - excess).clamp(0.0, 1.0);
      lockedSum = 1.0;
    }

    // 剩余空间分配给未锁定的 RO
    double remainingSpace = (1.0 - lockedSum).clamp(0.0, 1.0);

    if (unlockedFormulas.isNotEmpty) {
      // 计算其他未锁定 RO 的当前总和
      double unlockedSum = 0.0;
      for (final formula in unlockedFormulas) {
        unlockedSum += widget.molarAmounts[formula] ?? 0.0;
      }

      // 如果未锁定的 RO 当前总和为 0，则平均分配
      if (unlockedSum == 0.0) {
        final sharePerFormula = remainingSpace / unlockedFormulas.length;
        for (final formula in unlockedFormulas) {
          widget.molarAmounts[formula] = sharePerFormula;
        }
      } else {
        // 否则按当前比例重新分配剩余空间
        for (final formula in unlockedFormulas) {
          final currentValue = widget.molarAmounts[formula] ?? 0.0;
          final ratio = currentValue / unlockedSum;
          widget.molarAmounts[formula] = remainingSpace * ratio;
        }
      }
    }
    widget.onDataChanged();
  }

  /// 构建单个化学式项
  Widget _buildFormulaCard(ChemicalFormula formula) {
    final molarAmount = widget.molarAmounts[formula] ?? 0.0;
    final massAmount = _massAmounts[formula] ?? 0.0;
    final isRO = formula.isRO;
    final isLocked = widget.lockedFormulas.contains(formula);
    final massPercentage = _calculateMassPercentage(formula);
    final isMolarMode = _inputMode == SegerInputMode.molar;

    // 计算 RO 的可编辑性和范围（仅摩尔量模式下生效）
    bool isROEditable = true;
    double maxROValue = 1.0;

    if (isRO && isMolarMode) {
      // 统计其他RO的情况（排除自身）
      int otherUnlockedCount = 0; // 其他未锁定RO的数量
      double otherLockedSum = 0.0; // 其他已锁定RO的总和

      for (final f in widget.selectedFormulas) {
        if (f.isRO && f != formula) {
          if (widget.lockedFormulas.contains(f)) {
            otherLockedSum += widget.molarAmounts[f] ?? 0.0;
          } else {
            otherUnlockedCount++;
          }
        }
      }

      // 规则2：其他未锁定RO数量 < 1 时，不可编辑
      isROEditable = otherUnlockedCount >= 1;

      // 规则3：最大值 = 1 - 除了自身（不管是否锁定）其他所有已锁定的RO总和
      maxROValue = (1.0 - otherLockedSum).clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：化学式名称、锁定按钮、数值、删除按钮
          Row(
            children: [
              // 化学式名称和锁定按钮
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      formula.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // 锁定按钮（仅摩尔量模式下的 RO 类显示）
                  if (isRO && isMolarMode)
                    InkWell(
                      onTap: () {
                        // 切换锁定状态，不改变任何值
                        if (isLocked) {
                          widget.lockedFormulas.remove(formula);
                        } else {
                          widget.lockedFormulas.add(formula);
                        }
                        widget.onDataChanged();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isLocked ? Icons.lock : Icons.lock_open,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 8),

              // 输入框和附加信息（垂直排列）
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 36,
                        child: TextField(
                          enabled: isMolarMode ? (!isRO || isROEditable) : true,
                          controller: getOrCreateController(formula, _getFormulaText),
                          focusNode: getOrCreateFocusNode(formula),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            if (isMolarMode && isRO)
                              _ROInputFormatter(maxValue: maxROValue)
                            else
                              DecimalInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            isDense: true,
                            hintText: isMolarMode
                                ? (isRO ? '0.00-1.00' : '摩尔量')
                                : '质量',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (value) {
                            final newValue = double.tryParse(value) ?? 0.0;
                            if (isMolarMode) {
                              // 摩尔量模式
                              if (isRO) {
                                // RO 类：inputFormatter已经限制了输入范围，直接调用 _adjustRO
                                _adjustRO(formula, newValue);
                                // 更新其他 RO 的输入框文本
                                for (final f in widget.selectedFormulas) {
                                  if (f.isRO && f != formula) {
                                    updateControllerText(f, _getFormulaText);
                                  }
                                }
                              } else {
                                // 非 RO 类直接设置值
                                widget.molarAmounts[formula] = newValue;
                                widget.onDataChanged();
                              }
                            } else {
                              // 质量模式：根据质量计算摩尔量
                              _updateMolarFromMass(formula, newValue);
                            }
                          },
                        ),
                      ),
                      // 附加信息显示
                      if (isMolarMode) ...[
                        // 摩尔量模式：显示质量占比
                        if (molarAmount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '质量占比: ${massPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ] else ...[
                        // 质量模式：显示计算出的摩尔量
                        if (massAmount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '摩尔量: ${molarAmount.toStringAsFixed(3)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 删除按钮（与锁定按钮分开,避免误操作）
              InkWell(
                onTap: () async {
                  final confirm = await showDeleteConfirmDialog(context, formula.name);
                  if (confirm == true) {
                    if (isRO && isMolarMode) {
                      // 删除RO时，将其值分配给最新添加的RO（仅摩尔量模式）
                      final deletedValue = widget.molarAmounts[formula] ?? 0.0;

                      // 找到最新添加的RO（除了当前要删除的）
                      final remainingROs = widget.selectedFormulas
                          .where((f) => f.isRO && f != formula)
                          .toList();

                      if (remainingROs.isNotEmpty) {
                        // 最新添加的是列表中的最后一个
                        final newestRO = remainingROs.last;
                        widget.molarAmounts[newestRO] =
                            (widget.molarAmounts[newestRO] ?? 0.0) + deletedValue;
                        // 更新最新RO的输入框文本
                        updateControllerText(newestRO, _getFormulaText);
                      }
                    }

                    widget.selectedFormulas.remove(formula);
                    widget.molarAmounts.remove(formula);
                    widget.lockedFormulas.remove(formula);
                    _massAmounts.remove(formula);
                    widget.onDataChanged();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red[400],
                  ),
                ),
              ),
            ],
          ),

          // 第二行：RO 类的滑块（仅摩尔量模式下显示）
          if (isRO && isMolarMode) ...[
            const SizedBox(height: 4),
            Slider(
              value: molarAmount.clamp(0.0, maxROValue),
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: molarAmount.toStringAsFixed(2),
              onChanged: isROEditable
                  ? (value) {
                      // 规则3：限制value在允许范围内 [0, maxROValue]
                      final clampedValue = value.clamp(0.0, maxROValue);
                      _adjustRO(formula, clampedValue);
                      // 更新所有 RO 的输入框文本
                      for (final f in widget.selectedFormulas) {
                        if (f.isRO) {
                          updateControllerText(f, _getFormulaText);
                        }
                      }
                    }
                  : null, // 规则2：不可编辑时禁用Slider
            ),
          ],
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以保持状态
    final isMolarMode = _inputMode == SegerInputMode.molar;

    return Column(
      children: [
        // 模式切换行
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Text('输入模式:', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 12),
              SegmentedButton<SegerInputMode>(
                segments: const [
                  ButtonSegment(
                    value: SegerInputMode.molar,
                    label: Text('摩尔量'),
                    icon: Icon(Icons.science_outlined),
                  ),
                  ButtonSegment(
                    value: SegerInputMode.mass,
                    label: Text('质量'),
                    icon: Icon(Icons.scale_outlined),
                  ),
                ],
                selected: {_inputMode},
                onSelectionChanged: (Set<SegerInputMode> selected) {
                  _switchInputMode(selected.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        // 按钮行:添加化学式 + 计算矿物配比
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _showAddFormulaDialog,
                icon: const Icon(Icons.add),
                label: const Text('添加化学式'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: widget.selectedFormulas.isEmpty
                    ? null
                    : isMolarMode
                        ? widget.onConvertToMaterials
                        : _convertMassToSegerAndMaterials,
                icon: const Icon(Icons.calculate),
                label: const Text('计算矿物配比'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // 已选择的化学式列表（按分类分组显示）
        Expanded(
          child: widget.selectedFormulas.isEmpty
              ? const Center(
                  child: Text(
                    '点击"添加化学式"开始配制釉料',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _buildCategoryGroups(),
                ),
        ),
      ],
    );
  }

  // 显示添加化学式对话框
  void _showAddFormulaDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: ChemicalFormula.categoryMap.entries.map((entry) {
                final categoryName = entry.key;
                final formulas = entry.value;
                return ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    categoryName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: formulas.map((formula) {
                    final isSelected = widget.selectedFormulas.contains(formula);
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                      title: Text(formula.name),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        if (!isSelected) {
                          widget.selectedFormulas.add(formula);
                          if (formula.isRO) {
                            // 新添加的RO：计算当前所有RO的总和
                            double currentROSum = 0.0;
                            for (final f in widget.selectedFormulas) {
                              if (f.isRO && f != formula) {
                                currentROSum += widget.molarAmounts[f] ?? 0.0;
                              }
                            }
                            // 新RO的值 = 1 - 当前RO的总和
                            widget.molarAmounts[formula] = (1.0 - currentROSum).clamp(0.0, 1.0);
                          } else {
                            // 非RO类默认值为 0.0
                            widget.molarAmounts[formula] = 0.0;
                          }
                          widget.onDataChanged();
                        }
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

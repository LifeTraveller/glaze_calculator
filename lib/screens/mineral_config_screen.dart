import 'package:flutter/material.dart';
import '../models/chemical_formula.dart';
import '../models/mineral_formula.dart';

/// 矿物式配置页面 - 展示化学式和矿物式（只读）
class MineralConfigScreen extends StatefulWidget {
  const MineralConfigScreen({super.key});

  @override
  State<MineralConfigScreen> createState() => _MineralConfigScreenState();
}

class _MineralConfigScreenState extends State<MineralConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('原料配置'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: '矿物式'),
            Tab(icon: Icon(Icons.science), text: '化学式'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MineralTab(),
          ChemicalFormulaTab(),
        ],
      ),
    );
  }
}

/// 矿物式展示标签页（只读）
class MineralTab extends StatelessWidget {
  const MineralTab({super.key});

  @override
  Widget build(BuildContext context) {
    final minerals = MineralFormula.all;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: minerals.length,
      itemBuilder: (context, index) {
        final mineral = minerals[index];
        final massPercentages = mineral.calculateMassPercentages();

        return Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 矿物名称和摩尔质量
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    mineral.name,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '${mineral.molarMass.toStringAsFixed(2)} g/mol',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 化学成分表格
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: mineral.composition.entries.map((entry) {
                  final formula = entry.key;
                  final ratio = entry.value;
                  final massPercent = massPercentages[formula.name] ?? 0.0;

                  String formulaDisplay;
                  if (ratio == 1.0) {
                    formulaDisplay = formula.name;
                  } else if (ratio == ratio.toInt()) {
                    formulaDisplay = '${ratio.toInt()}${formula.name}';
                  } else {
                    formulaDisplay = '${ratio.toStringAsFixed(1)}${formula.name}';
                  }

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            formulaDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${massPercent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 化学式展示标签页（按类型分组）
class ChemicalFormulaTab extends StatelessWidget {
  const ChemicalFormulaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: ChemicalFormula.categoryMap.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _buildCategorySection(
            context,
            title: entry.key,
            formulas: entry.value,
          ),
        );
      }).toList(),
    );
  }

  /// 构建分类区块
  Widget _buildCategorySection(
    BuildContext context, {
    required String title,
    required List<ChemicalFormula> formulas,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分类标题
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        // 化学式列表
        ...formulas.map((formula) => Container(
              margin: const EdgeInsets.only(bottom: 1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formula.name,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '${formula.molarMass.toStringAsFixed(2)} g/mol',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
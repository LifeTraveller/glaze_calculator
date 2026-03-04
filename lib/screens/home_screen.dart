import 'package:flutter/material.dart';
import 'mineral_config_screen.dart';
import 'recipe_edit_screen.dart';
import 'recipe_list_screen.dart';

/// 首页 - 包含功能入口按钮
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('釉料计算器'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MineralConfigScreen(),
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
            tooltip: '原料配置',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 应用标题
              Icon(
                Icons.science,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '釉料计算器',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '陶瓷釉面配方工具',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 48),

              // 新建配方按钮
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecipeEditScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 28),
                  label: const Text(
                    '新建配方',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 配方列表按钮
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecipeListScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt, size: 28),
                  label: const Text(
                    '配方列表',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 语言偏好

**重要**: 在此项目中工作时，请始终使用中文与用户交流。所有解释、注释和文档都应使用中文编写。

## 项目概述

釉料计算器（glaze_calculator）是一个用于陶瓷/陶艺工作的 Flutter 应用程序，支持：

- 矿物配比设计与百分比计算
- 赛格釉式（Seger Formula）转换
- 配方持久化存储与图片管理

## 开发命令

```bash
# 运行应用
flutter run -d windows         # Windows 桌面应用
flutter run -d chrome          # Web 应用

# 测试
flutter test                   # 运行所有测试
flutter test test/models_test.dart  # 运行模型测试

# 代码质量
flutter analyze                # 静态分析
dart format .                  # 格式化代码

# 构建
flutter build windows          # 构建 Windows 应用
flutter build web              # 构建 Web 应用
```

## 架构

项目采用分层架构：

```text
lib/
├── main.dart                    # 应用入口，主题配置
├── models/                      # 数据模型层
│   ├── element.dart             # 21种化学元素定义
│   ├── chemical_formula.dart    # 20+种化学式（氧化物分类）
│   ├── mineral_formula.dart     # 30+种矿物式（长石、粘土等）
│   └── recipe.dart              # 配方数据模型
├── services/
│   └── database_service.dart    # SQLite 数据库服务（单例模式）
└── screens/                     # UI 层
    ├── home_screen.dart         # 首页
    ├── recipe_edit_screen.dart  # 核心编辑器（矿物配比/赛格釉式）
    ├── recipe_list_screen.dart  # 配方列表
    ├── save_recipe_screen.dart  # 保存/编辑配方
    └── mineral_config_screen.dart # 原料配置查阅
```

## 核心数据模型

### 化学式分类 (ChemicalFormula)

- **碱性氧化物 (RO)**: K₂O、Na₂O、CaO、MgO、BaO、SrO、Li₂O、ZnO、PbO
- **中性氧化物 (R₂O₃)**: Al₂O₃、B₂O₃、P₂O₅
- **酸性氧化物 (RO₂)**: SiO₂、TiO₂、SnO₂、ZrO₂
- **着色氧化物**: Fe₂O₃、CuO、CoO、Cr₂O₃、MnO₂、NiO

### 矿物式 (MineralFormula)

- 支持"烧成前"和"烧成后"组成差异（处理 H₂O、CO₂ 挥发）
- 预设包括：钾长石、钠长石、高岭土、滑石、白云石、硼砂等

## 核心算法

### 正向转换（矿物 → 赛格釉式）

1. 计算每个矿物的摩尔量 = 质量百分比 / 摩尔质量
2. 汇总所有化学式的摩尔量
3. 按 RO 类总和归一化（赛格釉式标准要求 RO = 1）

### 反向转换（赛格釉式 → 矿物）

使用最小二乘法求解线性方程组 **A·x = b**：

- A：矿物提供的化学式系数矩阵
- x：矿物百分比（未知数）
- b：目标化学式摩尔量
- 实现：高斯消元法，含非负约束和误差分析

## 数据库结构

```sql
CREATE TABLE recipes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  mineral_amounts TEXT NOT NULL,  -- JSON 格式
  image_paths TEXT NOT NULL       -- JSON 格式
)
```

## 关键实现细节

- **百分比自动调整**：修改一个矿物时自动调整其他未锁定矿物，保持总和为 100%
- **矿物锁定机制**：防止关键矿物被自动调整（`lockedMinerals` Set）
- **图片管理**：图片复制到应用目录，删除配方时自动清理关联文件
- **主编辑器**：`RecipeEditScreen` 包含双标签页（MineralRatioTab / SegerFormulaTab）

## 主要依赖

- **sqflite**: 本地 SQLite 数据库
- **image_picker**: 照片选择和拍照
- **path_provider**: 应用目录路径获取

## 代码规范

- 代码注释：中文
- 变量和函数名：英文（Dart 命名约定）
- UI 文本和错误消息：中文
- 代码质量：flutter_lints ^5.0.0
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UI 通用工具函数和组件

/// 显示信息提示对话框
Future<void> showInfoDialog(
  BuildContext context,
  String message, {
  String title = '提示',
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

/// 显示删除确认对话框
Future<bool?> showDeleteConfirmDialog(
  BuildContext context,
  String itemName, {
  String? customMessage,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('确认删除'),
      content: Text(customMessage ?? '确定要删除 $itemName 吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            '删除',
            style: TextStyle(color: Colors.red[600]),
          ),
        ),
      ],
    ),
  );
}

/// 显示成功提示消息
void showSuccessMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.green[700],
      duration: const Duration(seconds: 2),
    ),
  );
}

/// 显示错误提示消息
void showErrorMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red[700],
      duration: const Duration(seconds: 3),
    ),
  );
}

/// 显示普通提示消息
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

/// 通用数值输入格式化器 - 限制格式和小数位数（最多2位）
/// 用于矿物质量和非RO化学式输入
class DecimalInputFormatter extends TextInputFormatter {
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

    // 负数不允许
    if (value < 0) {
      return oldValue;
    }

    // 限制格式：不允许前导零（除了"0"本身和"0."开头的小数）
    // 允许：0, 0.1, 0.12, 1, 12, 12.34
    // 不允许：01, 001, 0123
    final pattern = RegExp(r'^(0|[1-9]\d*)(\.\d{0,2})?$');
    if (!pattern.hasMatch(newValue.text)) {
      return oldValue;
    }

    return newValue;
  }
}

/// 输入控制器管理 Mixin - 用于管理 TextEditingController 和 FocusNode
mixin InputControllerManager<T> {
  final Map<T, TextEditingController> _controllers = {};
  final Map<T, FocusNode> _focusNodes = {};

  /// 获取或创建文本控制器
  TextEditingController getOrCreateController(
    T key,
    String Function(T) textProvider,
  ) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: textProvider(key));
    }
    return _controllers[key]!;
  }

  /// 获取或创建焦点节点
  FocusNode getOrCreateFocusNode(T key) {
    if (!_focusNodes.containsKey(key)) {
      _focusNodes[key] = FocusNode();
    }
    return _focusNodes[key]!;
  }

  /// 更新控制器文本（只有在输入框没有焦点时才更新）
  void updateControllerText(T key, String Function(T) textProvider) {
    final controller = _controllers[key];
    final focusNode = _focusNodes[key];

    // 如果输入框有焦点（用户正在编辑），不更新
    if (focusNode != null && focusNode.hasFocus) {
      return;
    }

    if (controller != null) {
      final newText = textProvider(key);
      if (controller.text != newText) {
        controller.text = newText;
      }
    }
  }

  /// 强制更新控制器文本（忽略焦点状态，用于模式切换等场景）
  void forceUpdateControllerText(T key, String Function(T) textProvider) {
    final controller = _controllers[key];
    if (controller != null) {
      final newText = textProvider(key);
      if (controller.text != newText) {
        controller.text = newText;
      }
    }
  }

  /// 清理不再存在的项的controller和焦点节点
  void cleanupRemovedItems(Set<T> currentItems) {
    final removedItems = _controllers.keys
        .where((item) => !currentItems.contains(item))
        .toList();

    for (final item in removedItems) {
      _controllers[item]?.dispose();
      _controllers.remove(item);
      _focusNodes[item]?.dispose();
      _focusNodes.remove(item);
    }
  }

  /// 释放所有资源
  void disposeAllResources() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
  }
}

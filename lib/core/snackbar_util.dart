import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// 全局 SnackBar 工具类
class SnackbarUtil {
  SnackbarUtil._();

  static void success(BuildContext context, String message) {
    _show(context, message, AppTheme.success, Icons.check_circle);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, AppTheme.error, Icons.error);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message, AppTheme.warning, Icons.warning);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, const Color(0xFF42A5F5), Icons.info);
  }

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

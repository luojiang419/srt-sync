import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../screens/home_screen.dart';
import '../screens/project_screen.dart';
import '../screens/settings_screen.dart';

/// 自定义页面过渡
CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// GoRouter 路由表
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      pageBuilder: (context, state) =>
          _fadeTransition(state, const HomeScreen()),
    ),
    GoRoute(
      path: '/project/:id',
      name: 'project',
      pageBuilder: (context, state) {
        final projectId = state.pathParameters['id']!;
        return _fadeTransition(state, ProjectScreen(projectId: projectId));
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) =>
          _fadeTransition(state, const SettingsScreen()),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Color(0xFF9E9E9E)),
          const SizedBox(height: 16),
          Text(
            context.loc.t('error_page_not_found'),
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(context.loc.t('error_page_back_home')),
          ),
        ],
      ),
    ),
  ),
);

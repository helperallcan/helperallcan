import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/env.dart';
import 'core/router_refresh.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'features/auth/login_page.dart';
import 'features/chat/chat_page.dart';
import 'features/helper/helper_profile_page.dart';
import 'features/home/home_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/profile/profile_page.dart';
import 'features/tasks/create_task_page.dart';
import 'features/tasks/task_detail_page.dart';
import 'features/tasks/task_list_page.dart';
import 'features/tasks/task_tracking_page.dart';
import 'models/task.dart';

class HelperApp extends StatelessWidget {
  const HelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Env.isConfigured) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: const _MissingConfigPage(),
      );
    }

    return MaterialApp.router(
      title: 'Helper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router(),
    );
  }
}

GoRouter? _cachedRouter;

GoRouter _router() {
  return _cachedRouter ??= GoRouter(
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentSession != null;
      final isLogin = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLogin) return '/login';
      if (isLoggedIn && isLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfilePage()),
      GoRoute(
        path: '/helper-profile',
        builder: (context, state) => const HelperProfilePage(),
      ),
      GoRoute(
          path: '/tasks', builder: (context, state) => const TaskListPage()),
      GoRoute(
        path: '/tasks/new/:kind',
        builder: (context, state) => CreateTaskPage(
          taskKind: taskKindFromValue(state.pathParameters['kind']),
        ),
      ),
      GoRoute(
        path: '/tasks/:id/tracking',
        builder: (context, state) => TaskTrackingPage(
          taskId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/tasks/:id',
        builder: (context, state) => TaskDetailPage(
          taskId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => ChatPage(
          conversationId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}

class _MissingConfigPage extends StatelessWidget {
  const _MissingConfigPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '请通过 --dart-define 设置 SUPABASE_URL 和 SUPABASE_ANON_KEY 后运行。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

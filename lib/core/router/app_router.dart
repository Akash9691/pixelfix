import 'package:go_router/go_router.dart';

import '../../features/compare/presentation/compare_screen.dart';
import '../../features/editor/presentation/editor_screen.dart';
import '../../features/gallery/presentation/my_edits_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/settings/presentation/ai_models_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/editor', builder: (_, __) => const EditorScreen()),
    GoRoute(path: '/compare', builder: (_, __) => const CompareScreen()),
    GoRoute(path: '/edits', builder: (_, __) => const MyEditsScreen()),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsScreen(),
      routes: [GoRoute(path: 'models', builder: (_, __) => const AiModelsScreen())],
    ),
  ],
);

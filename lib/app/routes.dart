import 'package:flutter/material.dart';

import '../screens/add_screen.dart';
import '../screens/library_screen.dart';
import '../screens/reader_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/story_screen.dart';
import '../screens/theme_editor.dart';
import '../screens/words_screen.dart';

/// Maps a route string (see `AppState.route`) to its screen.
Widget buildScreen(String route) {
  final i = route.indexOf(':');
  final name = i < 0 ? route : route.substring(0, i);
  final arg = i < 0 ? '' : route.substring(i + 1);
  return switch (name) {
    'add' => const AddScreen(),
    'words' => const WordsScreen(),
    'profile' => const ProfileScreen(),
    'stats' => const StatsScreen(),
    'settings' => switch (arg) {
      'appearance' => const AppearanceScreen(),
      'reader' => const ReaderSettingsScreen(),
      'layout' => const LayoutScreen(),
      'motion' => const MotionScreen(),
      'about' => const AboutScreen(),
      _ => const ProfileScreen(),
    },
    'reader' => ReaderScreen(id: arg),
    'story' => StoryScreen(id: arg),
    'theme' => ThemeEditorScreen(id: arg),
    _ => const LibraryScreen(),
  };
}

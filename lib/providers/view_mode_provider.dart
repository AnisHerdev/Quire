import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileViewModeNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('file_view_mode');
    if (saved != null) {
      state = saved;
    }
  }

  void toggle() {
    state = !state;
    _persist();
  }

  void setGrid(bool value) {
    state = value;
    _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('file_view_mode', state);
  }
}

final fileViewModeProvider = NotifierProvider<FileViewModeNotifier, bool>(
  FileViewModeNotifier.new,
);

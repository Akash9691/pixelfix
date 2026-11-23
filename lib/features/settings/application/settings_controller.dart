import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../ml/model_spec.dart';

class Settings {
  const Settings({
    this.themeMode = ThemeMode.dark,
    this.exportFormat = 'jpg',
    this.processing = ProcessingMode.auto,
    this.onboarded = false,
  });
  final ThemeMode themeMode;
  final String exportFormat;
  final ProcessingMode processing;
  final bool onboarded;

  Settings copyWith({ThemeMode? themeMode, String? exportFormat, ProcessingMode? processing, bool? onboarded}) => Settings(
        themeMode: themeMode ?? this.themeMode,
        exportFormat: exportFormat ?? this.exportFormat,
        processing: processing ?? this.processing,
        onboarded: onboarded ?? this.onboarded,
      );
}

/// Overridden in main() with the real instance, so reads are synchronous.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final settingsProvider = NotifierProvider<SettingsController, Settings>(SettingsController.new);

class SettingsController extends Notifier<Settings> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  Settings build() => Settings(
        themeMode: ThemeMode.values.byName(_p.getString('theme') ?? 'dark'),
        exportFormat: _p.getString('format') ?? 'jpg',
        processing: ProcessingMode.values.byName(_p.getString('mode') ?? 'auto'),
        onboarded: _p.getBool('onboarded') ?? false,
      );

  void setTheme(ThemeMode m) {
    _p.setString('theme', m.name);
    state = state.copyWith(themeMode: m);
  }

  void setFormat(String f) {
    _p.setString('format', f);
    state = state.copyWith(exportFormat: f);
  }

  void setProcessing(ProcessingMode m) {
    _p.setString('mode', m.name);
    state = state.copyWith(processing: m);
  }

  void finishOnboarding() {
    _p.setBool('onboarded', true);
    state = state.copyWith(onboarded: true);
  }
}

import 'package:flutter/material.dart';

// colours copied from the auth screens so community matches them
const _background = Color(0xFF061112);
const _cyan = Color(0xFF00E5D4);

final _white = Colors.white;

OutlineInputBorder _border(Color color, [double width = 1]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color, width: width),
  );
}

final communityTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: _background,
  canvasColor: const Color(0xFF0C1C1E),
  colorScheme: const ColorScheme.dark(
    primary: _cyan,
    onPrimary: _background,
    secondary: _cyan,
    surface: _background,
    onSurface: Colors.white,
    surfaceContainerHighest: Color(0xFF12262A),
    error: Colors.redAccent,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: _background,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: _white.withValues(alpha: 0.04),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: _white.withValues(alpha: 0.15)),
    ),
  ),
  dividerTheme: DividerThemeData(color: _white.withValues(alpha: 0.12)),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _white.withValues(alpha: 0.04),
    hintStyle: TextStyle(color: _white.withValues(alpha: 0.40)),
    labelStyle: TextStyle(color: _white.withValues(alpha: 0.60)),
    enabledBorder: _border(_white.withValues(alpha: 0.15)),
    border: _border(_white.withValues(alpha: 0.15)),
    focusedBorder: _border(_cyan, 1.5),
    errorBorder: _border(Colors.redAccent),
    focusedErrorBorder: _border(Colors.redAccent, 1.5),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _cyan,
      foregroundColor: _background,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: _cyan),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: _background,
    indicatorColor: _cyan.withValues(alpha: 0.25),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(color: selected ? _cyan : Colors.white70);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(fontSize: 12, color: selected ? _cyan : Colors.white70);
    }),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: _cyan,
    foregroundColor: _background,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: _white.withValues(alpha: 0.04),
    selectedColor: _cyan.withValues(alpha: 0.25),
    checkmarkColor: _cyan,
    side: BorderSide(color: _white.withValues(alpha: 0.15)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: SegmentedButton.styleFrom(
      foregroundColor: Colors.white,
      selectedBackgroundColor: _cyan,
      selectedForegroundColor: _background,
      side: BorderSide(color: _white.withValues(alpha: 0.15)),
    ),
  ),
);

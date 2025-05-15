import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  ThemeData get theme => _isDarkMode ? _darkTheme : _lightTheme;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  static final _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFe0c36a),
    scaffoldBackgroundColor: const Color(0xFF0E1928),
    cardColor: const Color(0xFF182B45),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white38),
    ),
    iconTheme: const IconThemeData(color: Color(0xFFe0c36a)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(const Color(0xFFe0c36a)),
      trackColor:
          WidgetStateProperty.all(const Color(0xFFe0c36a).withOpacity(0.5)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFFe0c36a),
      textColor: Colors.white,
    ),
  );

  static final _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFFe0c36a),
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.grey[100],
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black54),
      bodySmall: TextStyle(color: Colors.black38),
    ),
    iconTheme: const IconThemeData(color: Color(0xFFe0c36a)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(const Color(0xFFe0c36a)),
      trackColor:
          WidgetStateProperty.all(const Color(0xFFe0c36a).withOpacity(0.5)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFFe0c36a),
      textColor: Colors.black87,
    ),
  );
}

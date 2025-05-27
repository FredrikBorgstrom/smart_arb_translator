import 'package:console/console.dart';

/// Utility class for console text formatting and color management.
///
/// This class provides convenient methods for setting console text colors
/// to improve the user experience when displaying status messages, errors,
/// and success notifications in the command-line interface.
///
/// The class uses the console package to handle cross-platform terminal
/// color support and provides a simple API for common color operations.
class ConsoleUtils {
  /// Sets the console text color to bright green.
  ///
  /// This method is typically used for displaying success messages,
  /// completion notifications, or positive status indicators in the
  /// command-line interface.
  ///
  /// Example:
  /// ```dart
  /// ConsoleUtils.setBrightGreen();
  /// print('✅ Translation completed successfully!');
  /// ConsoleUtils.resetTextColor();
  /// ```
  static void setBrightGreen() {
    Console.setTextColor(2, bright: true);
  }

  /// Sets the console text color to bright red.
  ///
  /// This method is typically used for displaying error messages,
  /// warnings, or failure notifications in the command-line interface.
  ///
  /// Example:
  /// ```dart
  /// ConsoleUtils.setBrightRed();
  /// print('❌ Translation failed: API key not found');
  /// ConsoleUtils.resetTextColor();
  /// ```
  static void setBrightRed() {
    Console.setTextColor(1, bright: true);
  }

  /// Resets the console text color to the default.
  ///
  /// This method should be called after using colored text to ensure
  /// that subsequent console output returns to the normal appearance.
  /// It's good practice to always reset colors after displaying
  /// colored messages.
  ///
  /// Example:
  /// ```dart
  /// ConsoleUtils.setBrightGreen();
  /// print('Success message');
  /// ConsoleUtils.resetTextColor(); // Always reset after coloring
  /// print('Normal text');
  /// ```
  static void resetTextColor() {
    Console.resetTextColor();
  }
}

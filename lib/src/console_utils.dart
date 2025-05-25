import 'package:console/console.dart';

class ConsoleUtils {
  static void setBrightGreen() {
    Console.setTextColor(2, bright: true);
  }

  static void setBrightRed() {
    Console.setTextColor(1, bright: true);
  }

  static void resetTextColor() {
    Console.resetTextColor();
  }
}

import 'package:flutter/material.dart';

/// Minimal Design System - True minimalism through restraint
/// 
/// Core Principles:
/// 1. Radical simplification - remove all unnecessary elements
/// 2. Typography focus - clean hierarchy with generous spacing  
/// 3. Color restraint - maximum 3 colors (black, white, accent)
/// 4. Functional beauty - form follows function strictly
/// 5. Content hierarchy - clear visual priority through space and type
class MinimalDesign {
  
  // COLORS - Extremely limited palette
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF); 
  static const Color gray = Color(0xFF666666);
  static const Color lightGray = Color(0xFFE5E5E5);
  static const Color accent = Color(0xFF007AFF); // Single accent color
  static const Color red = Color(0xFFFF3B30); // For errors only
  
  // SPACING - Generous and systematic
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 16.0;
  static const double space4 = 24.0;
  static const double space5 = 32.0;
  static const double space6 = 48.0;
  static const double space8 = 64.0;
  
  // TYPOGRAPHY - Clean hierarchy, no decoration
  static const TextStyle title = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w300, // Light weight for elegance
    color: black,
    letterSpacing: -0.5,
  );
  
  static const TextStyle heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: black,
    letterSpacing: -0.2,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: black,
    height: 1.5,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: gray,
  );
  
  static const TextStyle small = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: gray,
  );
  
  // BUTTONS - Clean, functional, no decoration
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: black,
    foregroundColor: white,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: const RoundedRectangleBorder(),
    padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
    ),
  );
  
  static ButtonStyle secondaryButton = OutlinedButton.styleFrom(
    foregroundColor: black,
    backgroundColor: Colors.transparent,
    side: const BorderSide(color: lightGray, width: 1),
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: const RoundedRectangleBorder(),
    padding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
    ),
  );
  
  // INPUTS - Clean and functional
  static InputDecorationTheme inputTheme = InputDecorationTheme(
    border: const UnderlineInputBorder(
      borderSide: BorderSide(color: lightGray, width: 1),
    ),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: lightGray, width: 1),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: black, width: 2),
    ),
    filled: false,
    contentPadding: const EdgeInsets.symmetric(vertical: space2),
    hintStyle: caption,
    labelStyle: caption,
  );
  
  // LAYOUT - Maximum simplicity
  static const EdgeInsets screenPadding = EdgeInsets.all(space4);
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(vertical: space4);
  
  // NO SHADOWS, NO GRADIENTS, NO DECORATIVE EFFECTS
  // Beauty through restraint and proper proportions
  
  // UTILITY METHODS
  static Widget verticalSpace(double height) => SizedBox(height: height);
  static Widget horizontalSpace(double width) => SizedBox(width: width);
  
  static Widget divider() => Container(
    height: 1,
    color: lightGray,
    margin: const EdgeInsets.symmetric(vertical: space3),
  );
  
  static Widget section({required Widget child}) => Padding(
    padding: sectionPadding,
    child: child,
  );
  
  // THEME DATA
  static ThemeData theme = ThemeData(
    useMaterial3: false, // Use Material 2 for more control
    fontFamily: 'SF Pro Text', // Clean system font
    scaffoldBackgroundColor: white,
    appBarTheme: const AppBarTheme(
      backgroundColor: white,
      foregroundColor: black,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: heading,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButton),
    inputDecorationTheme: inputTheme,
    dividerTheme: const DividerThemeData(
      color: lightGray,
      thickness: 1,
      space: space4,
    ),
    cardTheme: const CardThemeData(
      color: white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(),
      margin: EdgeInsets.zero,
    ),
    // Remove all material effects
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
  );
}
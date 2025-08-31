import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Minimal Design System - True minimalism through restraint
/// 
/// Core Principles:
/// 1. Radical simplification - remove all unnecessary elements
/// 2. Typography focus - clean hierarchy with generous spacing  
/// 3. Color restraint - maximum 3 colors (primary, secondary, accent)
/// 4. Functional beauty - form follows function strictly
/// 5. Content hierarchy - clear visual priority through space and type
class MinimalDesign {
  
  // THEME STATE
  static bool _isDarkMode = false;
  static bool get isDarkMode => _isDarkMode;
  
  static void setDarkMode(bool isDark) {
    _isDarkMode = isDark;
  }
  
  // LIGHT MODE COLORS
  static const Color _lightPrimary = Color(0xFF000000);    // Black
  static const Color _lightSecondary = Color(0xFFFFFFFF);  // White
  static const Color _lightGray = Color(0xFF666666);
  static const Color _lightLightGray = Color(0xFFE5E5E5);
  
  // DARK MODE COLORS - Professional dark theme
  static const Color _darkPrimary = Color(0xFFFFFFFF);     // White text on dark
  static const Color _darkSecondary = Color(0xFF1C1C1E);  // Rich dark background
  static const Color _darkGray = Color(0xFF8E8E93);       // Muted text
  static const Color _darkLightGray = Color(0xFF38383A);  // Subtle borders
  
  // SHARED COLORS
  static const Color accent = Color(0xFF007AFF);          // iOS blue - universal
  static const Color red = Color(0xFFFF3B30);             // Error color - universal
  
  // ADAPTIVE COLORS - Change based on theme
  static Color get primary => _isDarkMode ? _darkPrimary : _lightPrimary;
  static Color get secondary => _isDarkMode ? _darkSecondary : _lightSecondary;
  static Color get gray => _isDarkMode ? _darkGray : _lightGray;
  static Color get lightGray => _isDarkMode ? _darkLightGray : _lightLightGray;
  
  // LEGACY SUPPORT - Keep original names for compatibility
  static Color get black => primary;
  static Color get white => secondary;
  
  // SPACING - Generous and systematic
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 16.0;
  static const double space4 = 24.0;
  static const double space5 = 32.0;
  static const double space6 = 48.0;
  static const double space8 = 64.0;
  
  // TYPOGRAPHY - Plus Jakarta Sans for music app elegance
  static TextStyle get title => GoogleFonts.plusJakartaSans(
    fontSize: 32,
    fontWeight: FontWeight.w300, // Light weight for elegance
    color: primary,
    letterSpacing: -0.5,
  );
  
  static TextStyle get heading => GoogleFonts.plusJakartaSans(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: primary,
    letterSpacing: -0.2,
  );
  
  static TextStyle get body => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: primary,
    height: 1.5,
  );
  
  static TextStyle get caption => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: gray,
  );
  
  static TextStyle get small => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: gray,
  );
  
  // BUTTONS - Clean, functional, adaptive
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: secondary,
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
  
  static ButtonStyle get secondaryButton => OutlinedButton.styleFrom(
    foregroundColor: primary,
    backgroundColor: Colors.transparent,
    side: BorderSide(color: lightGray, width: 1),
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
  
  // INPUTS - Clean and adaptive
  static InputDecorationTheme get inputTheme => InputDecorationTheme(
    border: UnderlineInputBorder(
      borderSide: BorderSide(color: lightGray, width: 1),
    ),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: lightGray, width: 1),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: primary, width: 2),
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
  
  static Widget get divider => Container(
    height: 1,
    color: lightGray,
    margin: const EdgeInsets.symmetric(vertical: space3),
  );
  
  static Widget section({required Widget child}) => Padding(
    padding: sectionPadding,
    child: child,
  );
  
  // THEME TOGGLE - Ultra minimalist
  static Widget buildThemeToggle(VoidCallback onToggle) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: Icon(
            key: ValueKey(isDarkMode),
            isDarkMode 
                ? Icons.dark_mode_outlined 
                : Icons.light_mode_outlined,
            size: 14,
            color: primary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
  
  // ADAPTIVE THEME DATA
  static ThemeData get theme => ThemeData(
    useMaterial3: false, // Use Material 2 for more control
    textTheme: GoogleFonts.plusJakartaSansTextTheme(), // Modern minimalist font for music apps
    scaffoldBackgroundColor: secondary,
    appBarTheme: AppBarTheme(
      backgroundColor: secondary,
      foregroundColor: primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: primary,
        letterSpacing: -0.2,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButton),
    inputDecorationTheme: inputTheme,
    dividerTheme: DividerThemeData(
      color: lightGray,
      thickness: 1,
      space: space4,
    ),
    cardTheme: CardThemeData(
      color: secondary,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      margin: EdgeInsets.zero,
    ),
    // Remove all material effects
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
  );
}
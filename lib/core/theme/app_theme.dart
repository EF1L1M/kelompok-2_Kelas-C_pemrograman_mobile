import 'package:flutter/material.dart';

// ============================================================================
// PATUNGIN HUMAN-CENTERED DESIGN SYSTEM
// Palet hangat bernuansa kertas kopi, daun botani, dan terakota yang akrab,
// jauh dari tampilan kotak abu-abu kaku.
// ============================================================================

class AppTheme {
  // Token utama (nama dipertahankan agar kompatibel di seluruh layar)
  static const Color primaryEmerald = Color(0xFF1B6B50); // Deep Botanical Forest
  static const Color secondaryTeal = Color(0xFF2D8A6E); // Warm Leaf Teal
  static const Color darkSlate = Color(0xFF1D2421); // Warm Charcoal Ink
  static const Color surfaceLight = Color(0xFFFAF6F0); // Warm Cream Paper

  // Token hangat tambahan untuk variasi pola & permukaan organik
  static const Color warmCream = Color(0xFFFAF6F0);
  static const Color warmSand = Color(0xFFF2ECE1);
  static const Color paperWhite = Color(0xFFFFFDF9);
  static const Color softBorder = Color(0xFFE6DDD0);
  static const Color mutedInk = Color(0xFF666E67);
  static const Color deepForest = Color(0xFF143C2E);
  static const Color terracotta = Color(0xFFD65A38);
  static const Color honeyAmber = Color(0xFFD48A14);
  static const Color sageWash = Color(0xFFE1EFE8);
  static const Color apricotWash = Color(0xFFFCEAE3);
  static const Color butterWash = Color(0xFFFDF3D8);
  static const Color lavenderWash = Color(0xFFEDE9F8);
  static const Color skyWash = Color(0xFFE3F0F7);

  // Warna status pembayaran (lebih hangat & manusiawi)
  static const Color statusUnpaid = Color(0xFFD65A38); // Terracotta Clay
  static const Color statusPending = Color(0xFFD98A16); // Warm Honey
  static const Color statusPaid = Color(0xFF1F7A5A); // Botanical Sage
  static const Color statusRejected = Color(0xFFC23B2B); // Brick Red

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryEmerald,
      primary: primaryEmerald,
      secondary: secondaryTeal,
      tertiary: terracotta,
      surface: paperWhite,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: warmCream,
      appBarTheme: const AppBarTheme(
        backgroundColor: warmCream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: darkSlate,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkSlate,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: softBorder,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: paperWhite,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: softBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paperWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paperWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        hintStyle: const TextStyle(color: Color(0xFF989F98), fontSize: 14),
        labelStyle: const TextStyle(color: mutedInk, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryEmerald, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: statusRejected, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: statusRejected, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryEmerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkSlate,
          side: const BorderSide(color: Color(0xFFD5CBB9), width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryEmerald,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryEmerald,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
        elevation: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: deepForest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

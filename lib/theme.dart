import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const maroon = Color(0xFF7A1E2C);
  static const maroonDark = Color(0xFF661824);
  static const gold = Color(0xFFD4AF37);
  static const goldDark = Color(0xFFB8860B);
  static const blue = Color(0xFF2A4D8F);
  static const orange = Color(0xFFE07B39);
  static const cream = Color(0xFFFBF7EE);
  static const neutral200 = Color(0xFFE5E5E5);
  static const neutral500 = Color(0xFF737373);
  static const neutral700 = Color(0xFF404040);
}

TextStyle display(double size, {Color color = C.maroon, FontWeight? weight, double? height}) =>
    GoogleFonts.marcellus(fontSize: size, color: color, fontWeight: weight, height: height);

TextStyle body(double size, {Color color = C.maroon, FontWeight? weight, double? height}) =>
    GoogleFonts.manrope(fontSize: size, color: color, fontWeight: weight, height: height);

TextStyle tamil(double size, {Color color = C.maroon, FontWeight? weight, double? height}) =>
    GoogleFonts.notoSerifTamil(fontSize: size, color: color, fontWeight: weight, height: height);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.maroon, primary: C.maroon, surface: C.cream),
    scaffoldBackgroundColor: C.cream,
  );
  return base.copyWith(textTheme: GoogleFonts.manropeTextTheme(base.textTheme));
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class AppTheme {
static const blue500 = Color(0xFF3B82F6);
static ThemeData get light => ThemeData(
useMaterial3: true,
colorScheme: ColorScheme.fromSeed(seedColor: blue500),
scaffoldBackgroundColor: const Color(0xFFF3F4F6), // gray-100
textTheme: GoogleFonts.notoSansJpTextTheme(),
appBarTheme: const AppBarTheme(
backgroundColor: Colors.white,
surfaceTintColor: Colors.white,
foregroundColor: Colors.black87,
elevation: 0,
),
);
}
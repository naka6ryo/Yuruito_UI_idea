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
surfaceTintColor: Color.fromARGB(255, 246, 247, 249),
foregroundColor: Colors.black87,
elevation: 0,
),
 // Global button styling
 // Button colors that depend on state (disabled vs enabled)
 filledButtonTheme: FilledButtonThemeData(
	 style: ButtonStyle(
		 backgroundColor: WidgetStateProperty.resolveWith((states) =>
			 states.contains(WidgetState.disabled) ? const Color(0xFFCBD5E1) : blue500),
		 foregroundColor: WidgetStateProperty.resolveWith((states) =>
			 states.contains(WidgetState.disabled) ? const Color(0xFF94A3B8) : Colors.white),
		 padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 14, horizontal: 24)),
		 shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
		 textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600)),
	 ),
 ),
 outlinedButtonTheme: OutlinedButtonThemeData(
		 style: ButtonStyle(
			 side: WidgetStateProperty.resolveWith((states) =>
					 states.contains(WidgetState.disabled) ? const BorderSide(color: Color(0xFFCBD5E1)) : BorderSide(color: blue500)),
				 foregroundColor: WidgetStateProperty.resolveWith((states) =>
					 states.contains(WidgetState.disabled) ? const Color(0xFF94A3B8) : blue500),
			 padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12, horizontal: 20)),
			 shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
		 ),
 ),
 textButtonTheme: TextButtonThemeData(
		 style: ButtonStyle(
			 foregroundColor: WidgetStateProperty.resolveWith((states) =>
					 states.contains(WidgetState.disabled) ? const Color(0xFF94A3B8) : blue500),
		 ),
 ),
 // Global styling for input fields (fill color, padding, rounded corners)
 inputDecorationTheme: InputDecorationTheme(
	 filled: true,
	 fillColor: const Color.fromARGB(255, 222, 232, 252),
	 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
	 border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
	 enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
	 focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
	 hintStyle: const TextStyle(color: Color.fromARGB(255, 131, 133, 216)),
	 // Make label and floating label color match the hint color per design
	 labelStyle: const TextStyle(color: Color.fromARGB(255, 131, 133, 216)),
	 floatingLabelStyle: const TextStyle(color: Color.fromARGB(255, 131, 133, 216))
 ),
);
}
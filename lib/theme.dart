import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        // Large headings — Playfair Display
        displayLarge:  GoogleFonts.playfairDisplay(
            fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        displayMedium: GoogleFonts.playfairDisplay(
            fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        displaySmall:  GoogleFonts.playfairDisplay(
            fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        headlineLarge: GoogleFonts.playfairDisplay(
            fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        headlineMedium: GoogleFonts.playfairDisplay(
            fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),

        // Body text — DM Sans
        bodyLarge:   GoogleFonts.dmSans(
            fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF0F172A)),
        bodyMedium:  GoogleFonts.dmSans(
            fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF0F172A)),
        bodySmall:   GoogleFonts.dmSans(
            fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF64748B)),
        labelLarge:  GoogleFonts.dmSans(
            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        labelMedium: GoogleFonts.dmSans(
            fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
        labelSmall:  GoogleFonts.dmSans(
            fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
      ),
    );
  }
}
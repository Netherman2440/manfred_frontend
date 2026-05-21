import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography helpers for the observational-memory UI (T4).
///
/// The design system specifies three font families:
///   - mono   → JetBrains Mono
///   - sans   → Switzer
///   - serif  → Fraunces (display / italic accents)
///
/// `Switzer` is not available on Google Fonts, so we substitute Inter as a
/// close geometric sans. Visual delta is acceptable for this iteration;
/// when the brand pack is locked we can swap in the real font asset.
final class ManfredFonts {
  const ManfredFonts._();

  static TextStyle mono(TextStyle base) =>
      GoogleFonts.jetBrainsMono(textStyle: base);

  // NOTE: Inter is a stand-in for Switzer (not on Google Fonts).
  static TextStyle sans(TextStyle base) => GoogleFonts.inter(textStyle: base);

  static TextStyle serif(TextStyle base) =>
      GoogleFonts.fraunces(textStyle: base);
}

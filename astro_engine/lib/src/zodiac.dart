/// Zodiac sign utilities.

const List<String> signNames = [
  'Aries',
  'Taurus',
  'Gemini',
  'Cancer',
  'Leo',
  'Virgo',
  'Libra',
  'Scorpio',
  'Sagittarius',
  'Capricorn',
  'Aquarius',
  'Pisces',
];

/// Get the zodiac sign name for an ecliptic longitude.
String signFromLon(double lon) {
  double normalized = lon % 360;
  if (normalized < 0) normalized += 360;
  return signNames[normalized ~/ 30];
}

/// Get the longitude within a sign (0-30°).
double signLonFromLon(double lon) {
  double normalized = lon % 360;
  if (normalized < 0) normalized += 360;
  return normalized % 30;
}

/// Normalize an angle to 0-360 range.
double normalizeDeg(double deg) {
  double r = deg % 360;
  return r < 0 ? r + 360 : r;
}

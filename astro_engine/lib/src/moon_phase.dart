/// Moon phase determination from Sun-Moon elongation.

import 'zodiac.dart';

/// Determine the moon phase name from the Sun and Moon ecliptic longitudes.
String moonPhase(double sunLon, double moonLon) {
  double elongation = normalizeDeg(moonLon - sunLon);

  if (elongation < 45) return 'New Moon';
  if (elongation < 90) return 'First Quarter';
  if (elongation < 135) return 'Second Quarter';
  if (elongation < 180) return 'Full Moon';
  if (elongation < 225) return 'Disseminating';
  if (elongation < 270) return 'Third Quarter';
  if (elongation < 315) return 'Balsamic';
  return 'New Moon';
}

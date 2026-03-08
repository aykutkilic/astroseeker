/// Sidereal time computation (Meeus Ch. 12).

import 'dart:math';
import 'zodiac.dart';

/// Compute Greenwich Mean Sidereal Time in degrees.
double gmst(double jd) {
  double T = (jd - 2451545.0) / 36525.0;
  double theta0 =
      280.46061837 +
      360.98564736629 * (jd - 2451545.0) +
      0.000387933 * T * T -
      T * T * T / 38710000.0;
  return normalizeDeg(theta0);
}

/// Compute Local Sidereal Time in degrees.
double lst(double jd, double lonDeg) {
  return normalizeDeg(gmst(jd) + lonDeg);
}

/// Compute Greenwich Apparent Sidereal Time in degrees.
double gast(double jd, double deltaPsi, double trueObliquity) {
  double correction = deltaPsi * cos(trueObliquity * pi / 180);
  return normalizeDeg(gmst(jd) + correction);
}

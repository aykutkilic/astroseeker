/// Ecliptic ↔ equatorial coordinate transforms (Meeus Ch. 13).

import 'dart:math';

/// Convert ecliptic coordinates to equatorial.
/// [lambda] = ecliptic longitude (degrees)
/// [beta] = ecliptic latitude (degrees)
/// [epsilon] = obliquity of the ecliptic (degrees)
/// Returns (rightAscension, declination) in degrees.
(double ra, double dec) eclipticToEquatorial(
    double lambda, double beta, double epsilon) {
  final l = lambda * pi / 180;
  final b = beta * pi / 180;
  final e = epsilon * pi / 180;

  final sinL = sin(l);
  final cosL = cos(l);
  final sinB = sin(b);
  final cosB = cos(b);
  final sinE = sin(e);
  final cosE = cos(e);

  double ra = atan2(sinL * cosE - sinB / cosB * sinE, cosL);
  double dec = asin(sinB * cosE + cosB * sinE * sinL);

  ra = ra * 180 / pi;
  if (ra < 0) ra += 360;

  return (ra, dec * 180 / pi);
}

/// Convert equatorial coordinates to ecliptic.
/// Returns (longitude, latitude) in degrees.
(double lon, double lat) equatorialToEcliptic(
    double ra, double dec, double epsilon) {
  final a = ra * pi / 180;
  final d = dec * pi / 180;
  final e = epsilon * pi / 180;

  final sinA = sin(a);
  final cosA = cos(a);
  final sinD = sin(d);
  final cosD = cos(d);
  final sinE = sin(e);
  final cosE = cos(e);

  double lon = atan2(sinA * cosE + sinD / cosD * sinE, cosA);
  double lat = asin(sinD * cosE - cosD * sinE * sinA);

  lon = lon * 180 / pi;
  if (lon < 0) lon += 360;

  return (lon, lat * 180 / pi);
}

/// Moon position using ELP2000 truncated series (Meeus Ch. 47).

import 'dart:math';
import 'zodiac.dart';

class MoonPosition {
  final double lon;
  final double lat;
  final double dist; // km
  final double lonSpeed;
  final double latSpeed;

  const MoonPosition({
    required this.lon,
    required this.lat,
    required this.dist,
    required this.lonSpeed,
    required this.latSpeed,
  });
}

/// Compute the Moon's geocentric ecliptic position.
/// [T] = Julian centuries from J2000.0, [deltaPsi] = nutation in longitude (degrees).
MoonPosition moonPosition(double T, double deltaPsi) {
  // Fundamental arguments (degrees)
  // L' = Moon's mean longitude (mean equinox of date)
  double Lp = 218.3164477 +
      481267.88123421 * T -
      0.0015786 * T * T +
      T * T * T / 538841.0 -
      T * T * T * T / 65194000.0;

  // D = Mean elongation of the Moon
  double D = 297.8501921 +
      445267.1114034 * T -
      0.0018819 * T * T +
      T * T * T / 545868.0 -
      T * T * T * T / 113065000.0;

  // M = Sun's mean anomaly
  double M = 357.5291092 +
      35999.0502909 * T -
      0.0001536 * T * T +
      T * T * T / 24490000.0;

  // M' = Moon's mean anomaly
  double Mp = 134.9633964 +
      477198.8675055 * T +
      0.0087414 * T * T +
      T * T * T / 69699.0 -
      T * T * T * T / 14712000.0;

  // F = Moon's argument of latitude
  double F = 93.2720950 +
      483202.0175233 * T -
      0.0036539 * T * T -
      T * T * T / 3526000.0 +
      T * T * T * T / 863310000.0;

  // Three additional arguments
  double A1 = 119.75 + 131.849 * T;
  double A2 = 53.09 + 479264.290 * T;
  double A3 = 313.45 + 481266.484 * T;

  // Eccentricity correction factor
  double E = 1 - 0.002516 * T - 0.0000074 * T * T;
  double E2 = E * E;

  // Convert to radians for trig
  double dr = pi / 180;

  double Dr = D * dr, Mr = M * dr, Mpr = Mp * dr, Fr = F * dr;
  double A1r = A1 * dr, A2r = A2 * dr, A3r = A3 * dr;

  // ── Longitude terms ────────────────────────────────────────────────
  // [D, M, M', F, coeff_l]
  // Coefficients where M factor is ±1 must be multiplied by E
  // Coefficients where M factor is ±2 must be multiplied by E²
  double sumL = 0;
  for (final t in _lonTerms) {
    double arg = t[0] * Dr + t[1] * Mr + t[2] * Mpr + t[3] * Fr;
    double coeff = t[4];
    int mAbs = t[1].abs().toInt();
    if (mAbs == 1) coeff *= E;
    if (mAbs == 2) coeff *= E2;
    sumL += coeff * sin(arg);
  }

  // Additional corrections
  sumL += 3958 * sin(A1r) + 1962 * sin((Lp - F) * dr) + 318 * sin(A2r);

  // ── Latitude terms ─────────────────────────────────────────────────
  double sumB = 0;
  for (final t in _latTerms) {
    double arg = t[0] * Dr + t[1] * Mr + t[2] * Mpr + t[3] * Fr;
    double coeff = t[4];
    int mAbs = t[1].abs().toInt();
    if (mAbs == 1) coeff *= E;
    if (mAbs == 2) coeff *= E2;
    sumB += coeff * sin(arg);
  }

  sumB += -2235 * sin(Lp * dr) +
      382 * sin(A3r) +
      175 * sin((A1 - F) * dr) +
      175 * sin((A1 + F) * dr) +
      127 * sin((Lp - Mp) * dr) -
      115 * sin((Lp + Mp) * dr);

  // ── Distance terms ─────────────────────────────────────────────────
  double sumR = 0;
  for (final t in _distTerms) {
    double arg = t[0] * Dr + t[1] * Mr + t[2] * Mpr + t[3] * Fr;
    double coeff = t[4];
    int mAbs = t[1].abs().toInt();
    if (mAbs == 1) coeff *= E;
    if (mAbs == 2) coeff *= E2;
    sumR += coeff * cos(arg);
  }

  double lon = normalizeDeg(Lp + sumL / 1000000.0 + deltaPsi);
  double lat = sumB / 1000000.0;
  double dist = 385000.56 + sumR / 1000.0;

  // Speed via finite difference
  final dT = 1.0 / 36525.0; // 1 day in centuries
  final m1 = _rawMoonLonLat(T - dT * 0.5, deltaPsi);
  final m2 = _rawMoonLonLat(T + dT * 0.5, deltaPsi);
  double dlon = m2.$1 - m1.$1;
  if (dlon > 180) dlon -= 360;
  if (dlon < -180) dlon += 360;
  double dlat = m2.$2 - m1.$2;

  return MoonPosition(
    lon: lon,
    lat: lat,
    dist: dist,
    lonSpeed: dlon,
    latSpeed: dlat,
  );
}

(double, double) _rawMoonLonLat(double T, double deltaPsi) {
  double Lp = 218.3164477 +
      481267.88123421 * T -
      0.0015786 * T * T +
      T * T * T / 538841.0 -
      T * T * T * T / 65194000.0;
  double D = 297.8501921 +
      445267.1114034 * T -
      0.0018819 * T * T +
      T * T * T / 545868.0 -
      T * T * T * T / 113065000.0;
  double M = 357.5291092 +
      35999.0502909 * T -
      0.0001536 * T * T +
      T * T * T / 24490000.0;
  double Mp = 134.9633964 +
      477198.8675055 * T +
      0.0087414 * T * T +
      T * T * T / 69699.0 -
      T * T * T * T / 14712000.0;
  double F = 93.2720950 +
      483202.0175233 * T -
      0.0036539 * T * T -
      T * T * T / 3526000.0 +
      T * T * T * T / 863310000.0;
  double A1 = 119.75 + 131.849 * T;
  double A2 = 53.09 + 479264.290 * T;
  double E = 1 - 0.002516 * T - 0.0000074 * T * T;
  double E2 = E * E;
  double dr = pi / 180;
  double Dr = D * dr, Mr = M * dr, Mpr = Mp * dr, Fr = F * dr;

  double sumL = 0;
  for (final t in _lonTerms) {
    double arg = t[0] * Dr + t[1] * Mr + t[2] * Mpr + t[3] * Fr;
    double coeff = t[4];
    int mAbs = t[1].abs().toInt();
    if (mAbs == 1) coeff *= E;
    if (mAbs == 2) coeff *= E2;
    sumL += coeff * sin(arg);
  }
  sumL += 3958 * sin(A1 * dr) +
      1962 * sin((Lp - F) * dr) +
      318 * sin(A2 * dr);

  double sumB = 0;
  for (final t in _latTerms) {
    double arg = t[0] * Dr + t[1] * Mr + t[2] * Mpr + t[3] * Fr;
    double coeff = t[4];
    int mAbs = t[1].abs().toInt();
    if (mAbs == 1) coeff *= E;
    if (mAbs == 2) coeff *= E2;
    sumB += coeff * sin(arg);
  }
  double A3 = 313.45 + 481266.484 * T;
  sumB += -2235 * sin(Lp * dr) +
      382 * sin(A3 * dr) +
      175 * sin((A1 - F) * dr) +
      175 * sin((A1 + F) * dr) +
      127 * sin((Lp - Mp) * dr) -
      115 * sin((Lp + Mp) * dr);

  return (
    normalizeDeg(Lp + sumL / 1000000.0 + deltaPsi),
    sumB / 1000000.0,
  );
}

// ── Longitude periodic terms (Meeus Table 47.A) ─────────────────────
// [D, M, M', F, coefficient in units of 0.000001°]
const _lonTerms = <List<double>>[
  [0, 0, 1, 0, 6288774],
  [2, 0, -1, 0, 1274027],
  [2, 0, 0, 0, 658314],
  [0, 0, 2, 0, 213618],
  [0, 1, 0, 0, -185116],
  [0, 0, 0, 2, -114332],
  [2, 0, -2, 0, 58793],
  [2, -1, -1, 0, 57066],
  [2, 0, 1, 0, 53322],
  [2, -1, 0, 0, 45758],
  [0, 1, -1, 0, -40923],
  [1, 0, 0, 0, -34720],
  [0, 1, 1, 0, -30383],
  [2, 0, 0, -2, 15327],
  [0, 0, 1, 2, -12528],
  [0, 0, 1, -2, 10980],
  [4, 0, -1, 0, 10675],
  [0, 0, 3, 0, 10034],
  [4, 0, -2, 0, 8548],
  [2, 1, -1, 0, -7888],
  [2, 1, 0, 0, -6766],
  [1, 0, -1, 0, -5163],
  [1, 1, 0, 0, 4987],
  [2, -1, 1, 0, 4036],
  [2, 0, 2, 0, 3994],
  [4, 0, 0, 0, 3861],
  [2, 0, -3, 0, 3665],
  [0, 1, -2, 0, -2689],
  [2, 0, -1, 2, -2602],
  [2, -1, -2, 0, 2390],
  [1, 0, 1, 0, -2348],
  [2, -2, 0, 0, 2236],
  [0, 1, 2, 0, -2120],
  [0, 2, 0, 0, -2069],
  [2, -2, -1, 0, 2048],
  [2, 0, 1, -2, -1773],
  [2, 0, 0, 2, -1595],
  [4, -1, -1, 0, 1215],
  [0, 0, 2, 2, -1110],
  [3, 0, -1, 0, -892],
  [2, 1, 1, 0, -810],
  [4, -1, -2, 0, 759],
  [0, 2, -1, 0, -713],
  [2, 2, -1, 0, -700],
  [2, 1, -2, 0, 691],
  [2, -1, 0, -2, 596],
  [4, 0, 1, 0, 549],
  [0, 0, 4, 0, 537],
  [4, -1, 0, 0, 520],
  [1, 0, -2, 0, -487],
  [2, 1, 0, -2, -399],
  [0, 0, 2, -2, -381],
  [1, 1, 1, 0, 351],
  [3, 0, -2, 0, -340],
  [4, 0, -3, 0, 330],
  [2, -1, 2, 0, 327],
  [0, 2, 1, 0, -323],
  [1, 1, -1, 0, 299],
  [2, 0, 3, 0, 294],
];

// ── Latitude periodic terms (Meeus Table 47.B) ──────────────────────
const _latTerms = <List<double>>[
  [0, 0, 0, 1, 5128122],
  [0, 0, 1, 1, 280602],
  [0, 0, 1, -1, 277693],
  [2, 0, 0, -1, 173237],
  [2, 0, -1, 1, 55413],
  [2, 0, -1, -1, 46271],
  [2, 0, 0, 1, 32573],
  [0, 0, 2, 1, 17198],
  [2, 0, 1, -1, 9266],
  [0, 0, 2, -1, 8822],
  [2, -1, 0, -1, 8216],
  [2, 0, -2, -1, 4324],
  [2, 0, 1, 1, 4200],
  [2, 1, 0, -1, -3359],
  [2, -1, -1, 1, 2463],
  [2, -1, 0, 1, 2211],
  [2, -1, -1, -1, 2065],
  [0, 1, -1, -1, -1870],
  [4, 0, -1, -1, 1828],
  [0, 1, 0, 1, -1794],
  [0, 0, 0, 3, -1749],
  [0, 1, -1, 1, -1565],
  [1, 0, 0, 1, -1491],
  [0, 1, 1, 1, -1475],
  [0, 1, 1, -1, -1410],
  [0, 1, 0, -1, -1344],
  [1, 0, 0, -1, -1335],
  [0, 0, 3, 1, 1107],
  [4, 0, 0, -1, 1021],
  [4, 0, -1, 1, 833],
  [0, 0, 1, -3, 777],
  [4, 0, -2, 1, 671],
  [2, 0, 0, -3, 607],
  [2, 0, 2, -1, 596],
  [2, -1, 1, -1, 491],
  [2, 0, -2, 1, -451],
  [0, 0, 3, -1, 439],
  [2, 0, 2, 1, 422],
  [2, 0, -3, -1, 421],
  [2, 1, -1, 1, -366],
  [2, 1, 0, 1, -351],
  [4, 0, 0, 1, 331],
  [2, -1, 1, 1, 315],
  [2, -2, 0, -1, 302],
  [0, 0, 1, 3, -283],
  [2, 1, 1, -1, -229],
  [1, 1, 0, -1, 223],
  [1, 1, 0, 1, 223],
  [0, 1, -2, -1, -220],
  [2, 1, -1, -1, -220],
  [1, 0, 1, 1, -185],
  [2, -1, -2, -1, 181],
  [0, 1, 2, 1, -177],
  [4, 0, -2, -1, 176],
  [4, -1, -1, -1, 166],
  [1, 0, 1, -1, -164],
  [4, 0, 1, -1, 132],
  [1, 0, -1, -1, -119],
  [4, -1, 0, -1, 115],
  [2, -2, 0, 1, 107],
];

// ── Distance periodic terms (Meeus Table 47.A, cosine column) ────────
const _distTerms = <List<double>>[
  [0, 0, 1, 0, -20905355],
  [2, 0, -1, 0, -3699111],
  [2, 0, 0, 0, -2955968],
  [0, 0, 2, 0, -569925],
  [0, 1, 0, 0, 48888],
  [0, 0, 0, 2, -3149],
  [2, 0, -2, 0, 246158],
  [2, -1, -1, 0, -152138],
  [2, 0, 1, 0, -170733],
  [2, -1, 0, 0, -204586],
  [0, 1, -1, 0, -129620],
  [1, 0, 0, 0, 108743],
  [0, 1, 1, 0, 104755],
  [2, 0, 0, -2, 10321],
  [0, 0, 1, -2, 79661],
  [4, 0, -1, 0, -34782],
  [0, 0, 3, 0, -23210],
  [4, 0, -2, 0, -21636],
  [2, 1, -1, 0, 24208],
  [2, 1, 0, 0, 30824],
  [1, 0, -1, 0, -8379],
  [1, 1, 0, 0, -16675],
  [2, -1, 1, 0, -12831],
  [2, 0, 2, 0, -10445],
  [4, 0, 0, 0, -11650],
  [2, 0, -3, 0, 14403],
  [0, 1, -2, 0, -7003],
  [2, -1, -2, 0, 10056],
  [1, 0, 1, 0, 6322],
  [2, -2, 0, 0, -9884],
  [0, 1, 2, 0, 5751],
  [0, 2, 0, 0, -4950],
  [2, -2, -1, 0, 4130],
  [2, 0, 1, -2, -3958],
  [4, -1, -1, 0, 3258],
  [3, 0, -1, 0, 2616],
  [2, 1, 1, 0, -1897],
  [4, -1, -2, 0, -2117],
  [0, 2, -1, 0, 2354],
];

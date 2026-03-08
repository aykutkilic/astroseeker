/// Nutation and obliquity of the ecliptic (Meeus Ch. 22).

import 'dart:math';

/// Compute nutation in longitude (Δψ) and obliquity (Δε) in degrees,
/// plus the mean and true obliquity of the ecliptic.
///
/// Uses the IAU 1980 nutation theory with principal terms.
({double deltaPsi, double deltaEps, double meanObliquity, double trueObliquity})
    nutation(double T) {
  // Fundamental arguments (degrees)
  // D = Mean elongation of the Moon from the Sun
  double D = 297.85036 + 445267.111480 * T - 0.0019142 * T * T +
      T * T * T / 189474.0;
  // M = Mean anomaly of the Sun
  double M = 357.52772 + 35999.050340 * T - 0.0001603 * T * T -
      T * T * T / 300000.0;
  // M' = Mean anomaly of the Moon
  double Mp = 134.96298 + 477198.867398 * T + 0.0086972 * T * T +
      T * T * T / 56250.0;
  // F = Moon's argument of latitude
  double F = 93.27191 + 483202.017538 * T - 0.0036825 * T * T +
      T * T * T / 327270.0;
  // Ω = Longitude of the ascending node of the Moon's orbit
  double omega = 125.04452 - 1934.136261 * T + 0.0020708 * T * T +
      T * T * T / 450000.0;

  // Convert to radians
  final d = D * pi / 180;
  final m = M * pi / 180;
  final mp = Mp * pi / 180;
  final f = F * pi / 180;
  final o = omega * pi / 180;

  // Principal nutation terms (IAU 1980)
  // [D_mult, M_mult, Mp_mult, F_mult, omega_mult, psi_sin0, psi_sin1, eps_cos0, eps_cos1]
  const terms = <List<double>>[
    [0, 0, 0, 0, 1, -171996, -174.2, 92025, 8.9],
    [-2, 0, 0, 2, 2, -13187, -1.6, 5736, -3.1],
    [0, 0, 0, 2, 2, -2274, -0.2, 977, -0.5],
    [0, 0, 0, 0, 2, 2062, 0.2, -895, 0.5],
    [0, 1, 0, 0, 0, 1426, -3.4, 54, -0.1],
    [0, 0, 1, 0, 0, 712, 0.1, -7, 0],
    [-2, 1, 0, 2, 2, -517, 1.2, 224, -0.6],
    [0, 0, 0, 2, 1, -386, -0.4, 200, 0],
    [0, 0, 1, 2, 2, -301, 0, 129, -0.1],
    [-2, -1, 0, 2, 2, 217, -0.5, -95, 0.3],
    [-2, 0, 1, 0, 0, -158, 0, 0, 0],
    [-2, 0, 0, 2, 1, 129, 0.1, -70, 0],
    [0, 0, -1, 2, 2, 123, 0, -53, 0],
    [2, 0, 0, 0, 0, 63, 0, 0, 0],
    [0, 0, 1, 0, 1, 63, 0.1, -33, 0],
    [2, 0, -1, 2, 2, -59, 0, 26, 0],
    [0, 0, -1, 0, 1, -58, -0.1, 32, 0],
    [0, 0, 1, 2, 1, -51, 0, 27, 0],
    [-2, 0, 2, 0, 0, 48, 0, 0, 0],
    [0, 0, -2, 2, 1, 46, 0, -24, 0],
    [2, 0, 0, 2, 2, -38, 0, 16, 0],
    [0, 0, 2, 2, 2, -31, 0, 13, 0],
    [0, 0, 2, 0, 0, 29, 0, 0, 0],
    [-2, 0, 1, 2, 2, 29, 0, -12, 0],
    [0, 0, 0, 2, 0, 26, 0, 0, 0],
    [-2, 0, 0, 2, 0, -22, 0, 0, 0],
    [0, 0, -1, 2, 1, 21, 0, -10, 0],
    [0, 2, 0, 0, 0, 17, -0.1, 0, 0],
    [2, 0, -1, 0, 1, 16, 0, -8, 0],
    [-2, 2, 0, 2, 2, -16, 0.1, 7, 0],
    [0, 1, 0, 0, 1, -15, 0, 9, 0],
    [-2, 0, 1, 0, 1, -13, 0, 7, 0],
    [0, -1, 0, 0, 1, -12, 0, 6, 0],
    [0, 0, 2, -2, 0, 11, 0, 0, 0],
    [2, 0, -1, 2, 1, -10, 0, 5, 0],
    [2, 0, 1, 2, 2, -8, 0, 3, 0],
    [0, 1, 0, 2, 2, 7, 0, -3, 0],
    [-2, 1, 1, 0, 0, -7, 0, 0, 0],
    [0, -1, 0, 2, 2, -7, 0, 3, 0],
    [2, 0, 0, 2, 1, -7, 0, 3, 0],
    [2, 0, 1, 0, 0, -8, 0, 0, 0],
    [-2, 0, 2, 2, 2, 6, 0, -3, 0],
    [-2, 0, 1, 2, 1, 6, 0, -3, 0],
    [2, 0, -2, 0, 1, -6, 0, 3, 0],
    [2, 0, 0, 0, 1, -6, 0, 3, 0],
    [0, -1, 1, 0, 0, 5, 0, 0, 0],
    [-2, -1, 0, 2, 1, -5, 0, 3, 0],
    [-2, 0, 0, 0, 1, -5, 0, 3, 0],
    [0, 0, 2, 2, 1, -5, 0, 3, 0],
    [-2, 0, 2, 0, 1, 4, 0, 0, 0],
    [-2, 1, 0, 2, 1, 4, 0, 0, 0],
    [0, 0, 1, -2, 0, 4, 0, 0, 0],
    [-1, 0, 1, 0, 0, -4, 0, 0, 0],
    [-2, 1, 0, 0, 0, -4, 0, 0, 0],
    [1, 0, 0, 0, 0, -4, 0, 0, 0],
    [0, 0, 1, 2, 0, 3, 0, 0, 0],
    [0, 0, -2, 2, 2, -3, 0, 0, 0],
    [-1, -1, 1, 0, 0, -3, 0, 0, 0],
    [0, 1, 1, 0, 0, -3, 0, 0, 0],
    [0, -1, 1, 2, 2, -3, 0, 0, 0],
    [2, -1, -1, 2, 2, -3, 0, 0, 0],
    [0, 0, 3, 2, 2, -3, 0, 0, 0],
    [2, -1, 0, 2, 2, -3, 0, 0, 0],
  ];

  double deltaPsi = 0; // arcseconds
  double deltaEps = 0; // arcseconds

  for (final t in terms) {
    double arg = t[0] * d + t[1] * m + t[2] * mp + t[3] * f + t[4] * o;
    deltaPsi += (t[5] + t[6] * T) * sin(arg);
    deltaEps += (t[7] + t[8] * T) * cos(arg);
  }

  // Convert from 0.0001 arcseconds to degrees
  deltaPsi /= 36000000; // 0.0001" * 10000 → " → ° (divide by 3600*10000)
  deltaEps /= 36000000;

  // Mean obliquity of the ecliptic (Meeus eq. 22.3)
  double U = T / 100.0;
  double meanObliquity = 23.0 +
      26.0 / 60.0 +
      21.448 / 3600.0 -
      4680.93 / 3600.0 * U -
      1.55 / 3600.0 * U * U +
      1999.25 / 3600.0 * U * U * U -
      51.38 / 3600.0 * U * U * U * U -
      249.67 / 3600.0 * U * U * U * U * U -
      39.05 / 3600.0 * U * U * U * U * U * U +
      7.12 / 3600.0 * U * U * U * U * U * U * U +
      27.87 / 3600.0 * U * U * U * U * U * U * U * U +
      5.79 / 3600.0 * U * U * U * U * U * U * U * U * U +
      2.45 / 3600.0 * U * U * U * U * U * U * U * U * U * U;

  double trueObliquity = meanObliquity + deltaEps;

  return (
    deltaPsi: deltaPsi,
    deltaEps: deltaEps,
    meanObliquity: meanObliquity,
    trueObliquity: trueObliquity,
  );
}

/// Fixed star catalog with precession correction.
///
/// J2000.0 ecliptic coordinates for ~33 prominent fixed stars.
/// Precession is applied to bring positions to the date of the chart.

import 'models.dart';

/// Fixed star data: [name, lonJ2000, latJ2000, magnitude]
const List<List<dynamic>> _starCatalog = [
  ['Algenib', 9.0944, 12.6200, 2.84],
  ['Alpheratz', 14.2700, 25.6700, 2.06],
  ['Algol', 56.1300, 22.4000, 2.12],
  ['Alcyone', 59.9600, 4.0500, 2.87],
  ['Aldebaran', 69.7500, -5.4700, 0.86],
  ['Rigel', 76.7900, -31.1300, 0.13],
  ['Capella', 81.8200, 22.8600, 0.08],
  ['Betelgeuse', 88.7200, -16.0300, 0.42],
  ['Sirius', 104.05, -39.6000, -1.46],
  ['Canopus', 104.92, -75.8300, -0.74],
  ['Castor', 110.21, 10.0900, 1.58],
  ['Pollux', 113.19, 6.6800, 1.14],
  ['Procyon', 115.76, -16.0200, 0.37],
  ['Asellus Borealis', 127.51, 3.1900, 4.652],
  ['Asellus Australis', 128.70, 0.0800, 3.94],
  ['Alphard', 147.25, -22.3900, 1.97],
  ['Regulus', 149.80, 0.4600, 1.40],
  ['Denebola', 171.59, 12.2700, 2.13],
  ['Algorab', 193.43, -12.2000, 2.94],
  ['Spica', 203.82, -2.0500, 0.97],
  ['Arcturus', 204.21, 30.7500, -0.05],
  ['Alphecca', 222.27, 44.3300, 2.24],
  ['Zuben Eshamali', 229.35, 8.5000, 2.62],
  ['Unukalhai', 232.05, 25.5100, 2.63],
  ['Agena', 233.77, -44.1400, 0.60],
  ['Rigel Kentaurus', 239.49, -42.5900, -0.10],
  ['Antares', 249.74, -4.5700, 0.91],
  ['Lesath', 263.99, -14.0100, 2.70],
  ['Vega', 285.30, 61.7300, 0.03],
  ['Altair', 301.75, 29.3000, 0.76],
  ['Deneb Algedi', 323.52, -2.6000, 2.83],
  ['Fomalhaut', 333.83, -21.1300, 1.16],
  ['Deneb', 335.31, 59.9000, 1.25],
  ['Achernar', 345.28, -59.3700, 0.46],
];

/// Compute fixed star orb based on magnitude.
double _orbFromMag(double mag) {
  if (mag < 0.5) return 7.5;
  if (mag < 1.5) return 7.5;
  if (mag < 2.5) return 5.5;
  if (mag < 3.5) return 5.5;
  if (mag < 4.0) return 3.5;
  return 1.5;
}

/// Get all fixed stars with positions precessed to the given Julian centuries T.
///
/// Uses simplified precession: ~50.29" per year ≈ 1.3969° per century in longitude.
Map<String, dynamic> buildFixedStars(double T) {
  // General precession in longitude (degrees per Julian century)
  const precessionRate = 1.3969713; // ~50.29"/yr

  final precession = precessionRate * T;

  final result = <String, dynamic>{};
  for (final star in _starCatalog) {
    final name = star[0] as String;
    final lonJ2000 = star[1] as double;
    final latJ2000 = star[2] as double;
    final mag = star[3] as double;

    // Apply precession to longitude (latitude changes negligibly)
    final lon = lonJ2000 + precession;
    final lat = latJ2000;
    final orb = _orbFromMag(mag);

    result[name] = buildFixedStarJson(lon: lon, lat: lat, mag: mag, orb: orb);
  }
  return result;
}

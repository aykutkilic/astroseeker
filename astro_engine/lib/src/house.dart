/// Alcabitus house system computation.

import 'dart:math';
import 'zodiac.dart';
import 'models.dart';

/// Compute MC longitude from RAMC (Right Ascension of MC) and obliquity.
double mcFromRAMC(double ramc, double obliquity) {
  final ramcRad = ramc * pi / 180;
  final epsRad = obliquity * pi / 180;
  double mc = atan2(sin(ramcRad), cos(ramcRad) * cos(epsRad)) * 180 / pi;
  return normalizeDeg(mc);
}

/// Compute Ascendant from RAMC, obliquity, and geographic latitude.
double ascendant(double ramc, double obliquity, double geoLat) {
  final ramcRad = ramc * pi / 180;
  final epsRad = obliquity * pi / 180;
  final latRad = geoLat * pi / 180;

  double asc = atan2(
        cos(ramcRad),
        -(sin(ramcRad) * cos(epsRad) + tan(latRad) * sin(epsRad)),
      ) *
      180 /
      pi;
  return normalizeDeg(asc);
}

/// Compute Alcabitus house cusps.
///
/// The Alcabitus system trisects the diurnal and nocturnal semi-arcs
/// on the celestial equator, then projects to the ecliptic via the
/// MC formula (RA → ecliptic longitude).
///
/// Returns a list of 12 house cusp longitudes (index 0 = House 1 = Asc).
List<double> alcabitusHouseCusps(
    double ramc, double obliquity, double geoLat) {
  final ascLon = ascendant(ramc, obliquity, geoLat);
  final mcLon = mcFromRAMC(ramc, obliquity);

  final latRad = geoLat * pi / 180;

  // Declination and ascensional difference of the Ascendant
  double decAsc = _declination(ascLon, obliquity);
  double ad = asin(tan(latRad) * tan(decAsc * pi / 180)) * 180 / pi;
  double dsa = 90 + ad; // diurnal semi-arc
  double nsa = 90 - ad; // nocturnal semi-arc

  List<double> cusps = List.filled(12, 0);

  // Cusp 1 = Ascendant, Cusp 10 = MC
  cusps[0] = ascLon;
  cusps[9] = mcLon;

  // Trisect semi-arcs and project using MC formula (RA → ecliptic)
  double stepD = dsa / 3.0;
  double stepN = nsa / 3.0;

  // Cusps 11, 12: between MC and Asc (diurnal semi-arc trisection)
  cusps[10] = _eclipticFromRA(normalizeDeg(ramc + stepD), obliquity);
  cusps[11] = _eclipticFromRA(normalizeDeg(ramc + 2 * stepD), obliquity);

  // Cusps 2, 3: between Asc and IC (nocturnal semi-arc trisection)
  cusps[1] = _eclipticFromRA(normalizeDeg(ramc + dsa + stepN), obliquity);
  cusps[2] = _eclipticFromRA(normalizeDeg(ramc + dsa + 2 * stepN), obliquity);

  // IC = MC + 180°
  cusps[3] = normalizeDeg(mcLon + 180);

  // Opposite cusps (Houses 5-9 mirror Houses 11-3)
  cusps[4] = normalizeDeg(cusps[10] + 180); // House 5 = House 11 + 180°
  cusps[5] = normalizeDeg(cusps[11] + 180); // House 6 = House 12 + 180°
  cusps[6] = normalizeDeg(ascLon + 180);    // House 7 = Descendant
  cusps[7] = normalizeDeg(cusps[1] + 180);  // House 8 = House 2 + 180°
  cusps[8] = normalizeDeg(cusps[2] + 180);  // House 9 = House 3 + 180°

  return cusps;
}

/// Convert RA on the equator to ecliptic longitude using the MC formula.
/// This finds the ecliptic longitude whose right ascension equals [ra].
/// Formula: tan(λ) = tan(RA) / cos(ε)
double _eclipticFromRA(double ra, double obliquity) {
  final raRad = ra * pi / 180;
  final epsRad = obliquity * pi / 180;
  double lon = atan2(sin(raRad), cos(raRad) * cos(epsRad)) * 180 / pi;
  return normalizeDeg(lon);
}

/// Declination of a point on the ecliptic (beta=0).
double _declination(double lon, double obliquity) {
  return asin(sin(lon * pi / 180) * sin(obliquity * pi / 180)) * 180 / pi;
}

/// Build the houses JSON list.
List<Map<String, dynamic>> buildHouses(List<double> cusps, double ascLon) {
  List<Map<String, dynamic>> houses = [];
  for (int i = 0; i < 12; i++) {
    double nextCusp = cusps[(i + 1) % 12];
    double size = normalizeDeg(nextCusp - cusps[i]);
    bool isAbove = i >= 6;
    houses.add(buildHouseJson(
      num: i + 1,
      lon: cusps[i],
      size: size,
      isAboveHorizon: isAbove,
    ));
  }
  return houses;
}

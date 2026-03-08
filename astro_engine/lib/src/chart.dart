/// Main entry point — assembles a complete natal chart.

import 'julian.dart';
import 'nutation.dart';
import 'sidereal.dart';
import 'vsop87.dart';
import 'moon.dart';
import 'house.dart';
import 'angle.dart';
import 'fixed_stars.dart';
import 'moon_phase.dart';
import 'zodiac.dart';
import 'coord_transform.dart';
import 'models.dart';

/// Pure Dart natal chart calculator — no native dependencies.
class NatalChart {
  NatalChart._();

  /// Calculate a natal chart for the given UTC time and geographic position.
  ///
  /// Returns a `Map<String, dynamic>` matching the JSON contract expected
  /// by the frontend (same structure as the Python backend's `/natal` response).
  static Map<String, dynamic> calculate(
    DateTime utc,
    double geoLat,
    double geoLon,
  ) {
    final jd = dateTimeToJD(utc);
    final T = julianCenturies(jd);

    // Nutation & obliquity
    final nut = nutation(T);

    // Sidereal time
    final ramcDeg = lst(jd, geoLon); // RAMC = local sidereal time

    // ── Houses & Angles ──────────────────────────────────────────────
    final cusps = alcabitusHouseCusps(ramcDeg, nut.trueObliquity, geoLat);
    final ascLon = cusps[0];
    final mcLon = cusps[9]; // House 10 cusp = MC
    final houses = buildHouses(cusps, ascLon);
    final angles = buildAngles(ascLon, mcLon);

    // ── Sun ──────────────────────────────────────────────────────────
    final sun = sunPosition(jd, nut.deltaPsi);
    final sunEq = eclipticToEquatorial(sun.lon, sun.lat, nut.trueObliquity);

    // ── Moon ─────────────────────────────────────────────────────────
    final moon = moonPosition(T, nut.deltaPsi);
    final moonEq = eclipticToEquatorial(moon.lon, moon.lat, nut.trueObliquity);

    // ── Planets ──────────────────────────────────────────────────────
    final planets = <String, PlanetPosition>{};
    for (final name in ['Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn']) {
      planets[name] = planetPosition(name, jd, nut.deltaPsi);
    }

    // ── Lunar Nodes ──────────────────────────────────────────────────
    final nodeResult = _lunarNodes(T);
    final northNodeLon = normalizeDeg(nodeResult + nut.deltaPsi);
    final southNodeLon = normalizeDeg(northNodeLon + 180);
    // Mean node speed ≈ -0.05295° /day
    const nodeSpeed = -0.05295;

    // ── Syzygy (last new or full moon) ───────────────────────────────
    final syzygy = _lastSyzygy(jd, T, nut.deltaPsi);

    // ── Pars Fortuna ─────────────────────────────────────────────────
    final isDiurnal = _isDiurnal(sun.lon, ascLon);
    final parsLon = isDiurnal
        ? normalizeDeg(ascLon + moon.lon - sun.lon)
        : normalizeDeg(ascLon + sun.lon - moon.lon);

    // ── Build objects map ────────────────────────────────────────────
    final objects = <String, dynamic>{};

    objects['Sun'] = buildObjectJson(
      name: 'Sun', lon: sun.lon, lat: sun.lat,
      lonspeed: sun.lonSpeed, latspeed: sun.latSpeed,
      ra: sunEq.$1, dec: sunEq.$2,
    );
    objects['Moon'] = buildObjectJson(
      name: 'Moon', lon: moon.lon, lat: moon.lat,
      lonspeed: moon.lonSpeed, latspeed: moon.latSpeed,
      ra: moonEq.$1, dec: moonEq.$2,
    );

    for (final entry in planets.entries) {
      final p = entry.value;
      final eq = eclipticToEquatorial(p.lon, p.lat, nut.trueObliquity);
      objects[entry.key] = buildObjectJson(
        name: entry.key, lon: p.lon, lat: p.lat,
        lonspeed: p.lonSpeed, latspeed: p.latSpeed,
        ra: eq.$1, dec: eq.$2,
      );
    }

    objects['North Node'] = buildObjectJson(
      name: 'North Node', lon: northNodeLon, lat: 0,
      lonspeed: nodeSpeed, latspeed: 0,
    );
    objects['South Node'] = buildObjectJson(
      name: 'South Node', lon: southNodeLon, lat: 0,
      lonspeed: nodeSpeed, latspeed: 0,
    );
    objects['Syzygy'] = buildObjectJson(
      name: 'Syzygy', lon: syzygy.lon, lat: syzygy.lat,
      lonspeed: syzygy.lonSpeed, latspeed: syzygy.latSpeed,
    );
    objects['Pars Fortuna'] = buildObjectJson(
      name: 'Pars Fortuna', lon: parsLon, lat: 0,
      lonspeed: 0, latspeed: 0,
    );

    // ── Fixed Stars ──────────────────────────────────────────────────
    final fixedStars = buildFixedStars(T);

    // ── Moon Phase ───────────────────────────────────────────────────
    final phase = moonPhase(sun.lon, moon.lon);

    // ── General ──────────────────────────────────────────────────────
    // isHouse10MC: MC == House10 cusp (always true for Alcabitus)
    // isHouse1Asc: Asc == House1 cusp (always true for Alcabitus)
    final general = {
      'hsys': 'Alcabitus',
      'pos': {'lat': geoLat, 'lon': geoLon},
      'moonphase': phase,
      'isDiurnal': isDiurnal,
      'isHouse10MC': true,
      'isHouse1Asc': true,
    };

    return {
      'general': general,
      'objects': objects,
      'houses': houses,
      'angles': angles,
      'fixedStars': fixedStars,
    };
  }

  /// Calculate multiple charts stepping through time (for animation).
  static List<Map<String, dynamic>> calculateSteps({
    required DateTime utc,
    required double geoLat,
    required double geoLon,
    required int steps,
    required int stepMinutes,
  }) {
    final results = <Map<String, dynamic>>[];
    DateTime current = utc;
    for (int i = 0; i < steps; i++) {
      results.add(calculate(current, geoLat, geoLon));
      current = current.add(Duration(minutes: stepMinutes));
    }
    return results;
  }
}

// ── Helper: Mean longitude of the Moon's ascending node ──────────────

double _lunarNodes(double T) {
  // Meeus eq. 47.7 — mean longitude of ascending node
  return 125.0445479 -
      1934.1362891 * T +
      0.0020754 * T * T +
      T * T * T / 467441.0 -
      T * T * T * T / 60616000.0;
}

// ── Helper: Is the chart diurnal? ────────────────────────────────────

bool _isDiurnal(double sunLon, double ascLon) {
  // Sun is above the horizon if it's in the upper half of the chart
  // (between Desc and Asc going through MC)
  double descLon = normalizeDeg(ascLon + 180);
  double diff = normalizeDeg(sunLon - descLon);
  return diff <= 180;
}

// ── Helper: Last Syzygy (new or full moon before given JD) ───────────

class _SyzygyResult {
  final double lon;
  final double lat;
  final double lonSpeed;
  final double latSpeed;
  _SyzygyResult(this.lon, this.lat, this.lonSpeed, this.latSpeed);
}

_SyzygyResult _lastSyzygy(double jd, double T, double deltaPsi) {
  // Search backward for the last new moon or full moon
  // by finding where Sun-Moon elongation crosses 0° or 180°
  double searchJd = jd;
  const step = 1.0; // 1 day steps backward

  double prevSunLon = 0, prevMoonLon = 0;
  bool first = true;

  for (int i = 0; i < 35; i++) {
    final tStep = julianCenturies(searchJd);
    final nutStep = nutation(tStep);
    final sunStep = sunPosition(searchJd, nutStep.deltaPsi);
    final moonStep = moonPosition(tStep, nutStep.deltaPsi);

    double elong = normalizeDeg(moonStep.lon - sunStep.lon);

    if (!first) {
      double prevElong = normalizeDeg(prevMoonLon - prevSunLon);
      // Check for crossing 0° (new moon) or 180° (full moon)
      bool crossNew = (prevElong > 350 && elong < 10) ||
          (prevElong > 0 && prevElong < 10 && i > 0);
      bool crossFull = (prevElong > 170 && prevElong < 180 && elong > 180 && elong < 190) ||
          (prevElong < 190 && prevElong > 180 && elong > 170 && elong < 180);

      if (crossNew || crossFull) {
        // Return the Moon's position at this approximate syzygy
        return _SyzygyResult(
          moonStep.lon,
          moonStep.lat,
          moonStep.lonSpeed,
          moonStep.latSpeed,
        );
      }
    }

    prevSunLon = sunStep.lon;
    prevMoonLon = moonStep.lon;
    first = false;
    searchJd -= step;
  }

  // Fallback: return current Moon position
  final moonFb = moonPosition(T, deltaPsi);
  return _SyzygyResult(moonFb.lon, moonFb.lat, moonFb.lonSpeed, moonFb.latSpeed);
}

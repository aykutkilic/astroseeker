/// Data models matching the JSON contract expected by the frontend.

import 'zodiac.dart';
import 'antiscia.dart';

/// Default astrological orbs for each object.
const Map<String, double> defaultOrbs = {
  'Sun': 15,
  'Moon': 12,
  'Mercury': 7,
  'Venus': 7,
  'Mars': 8,
  'Jupiter': 9,
  'Saturn': 9,
  'Uranus': 6,
  'Neptune': 6,
  'Pluto': 5,
  'North Node': 12,
  'South Node': 12,
  'Syzygy': 0,
  'Pars Fortuna': 0,
};

Map<String, dynamic> buildObjectJson({
  required String name,
  required double lon,
  required double lat,
  required double lonspeed,
  required double latspeed,
  double ra = 0,
  double dec = 0,
  bool rootLevel = true,
}) {
  final orb = defaultOrbs[name] ?? 0;
  final isDirect = lonspeed > 0.0003;
  final isRetrograde = lonspeed < -0.0003;
  final isStationary = !isDirect && !isRetrograde;
  final movement = isDirect
      ? 'Direct'
      : (isRetrograde ? 'Retrograde' : 'Stationary');

  final result = <String, dynamic>{
    'type': rootLevel ? 'Planet' : 'Generic',
    'lat': lat,
    'lon': lon,
    'sign': signFromLon(lon),
    'signlon': signLonFromLon(lon),
    'latspeed': latspeed,
    'lonspeed': lonspeed,
    'orb': orb,
    'movement': movement,
    'isDirect': isDirect,
    'isPlanet': rootLevel,
    'isRetrograde': isRetrograde,
    'isStationary': isStationary,
  };

  if (rootLevel) {
    final aLon = antisciaLon(lon);
    final cLon = cantisciaLon(lon);
    result['antiscia'] = buildObjectJson(
      name: name,
      lon: aLon,
      lat: lat,
      lonspeed: lonspeed,
      latspeed: latspeed,
      rootLevel: false,
    );
    result['cantiscia'] = buildObjectJson(
      name: name,
      lon: cLon,
      lat: lat,
      lonspeed: lonspeed,
      latspeed: latspeed,
      rootLevel: false,
    );
  }

  return result;
}

Map<String, dynamic> buildHouseJson({
  required int num,
  required double lon,
  required double size,
  required bool isAboveHorizon,
}) {
  return {
    'type': 'House',
    'num': num,
    'lat': 0.0,
    'lon': lon,
    'sign': signFromLon(lon),
    'signlon': signLonFromLon(lon),
    'size': size,
    'isAboveHorizon': isAboveHorizon,
  };
}

Map<String, dynamic> buildAngleJson({
  required String id,
  required double lon,
  bool rootLevel = true,
}) {
  final result = <String, dynamic>{
    'type': 'Generic',
    'id': id,
    'lat': 0.0,
    'lon': lon,
    'sign': signFromLon(lon),
    'signlon': signLonFromLon(lon),
    'orb': -1.0,
  };

  if (rootLevel) {
    final aLon = antisciaLon(lon);
    final cLon = cantisciaLon(lon);
    // Note: the Python backend wraps antiscia in a list (bug/quirk).
    result['antiscia'] = [buildAngleJson(id: id, lon: aLon, rootLevel: false)];
    result['cantiscia'] = buildAngleJson(id: id, lon: cLon, rootLevel: false);
  }

  return result;
}

Map<String, dynamic> buildFixedStarJson({
  required double lon,
  required double lat,
  required double mag,
  required double orb,
}) {
  return {
    'type': 'Fixed Star',
    'lat': lat,
    'lon': lon,
    'mag': mag,
    'sign': signFromLon(lon),
    'signlon': signLonFromLon(lon),
    'orb': orb,
  };
}

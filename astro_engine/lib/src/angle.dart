/// Chart angles: Ascendant, MC, Descendant, IC.

import 'zodiac.dart';
import 'models.dart';

/// Build the angles JSON map.
Map<String, dynamic> buildAngles(double ascLon, double mcLon) {
  final descLon = normalizeDeg(ascLon + 180);
  final icLon = normalizeDeg(mcLon + 180);

  return {
    'Asc': buildAngleJson(id: 'Asc', lon: ascLon),
    'MC': buildAngleJson(id: 'MC', lon: mcLon),
    'Desc': buildAngleJson(id: 'Desc', lon: descLon),
    'IC': buildAngleJson(id: 'IC', lon: icLon),
  };
}

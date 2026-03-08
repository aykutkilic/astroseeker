/// Antiscia and contra-antiscia calculations.
///
/// Antiscia is the mirror image of a position across the Cancer-Capricorn axis.
/// Contra-antiscia is 180° from the antiscia point.

import 'zodiac.dart';

/// Compute the antiscia longitude: reflection across 0° Cancer (90°).
/// antiscia_lon = (180 - lon) mod 360
double antisciaLon(double lon) => normalizeDeg(180 - lon);

/// Compute the contra-antiscia longitude: 180° from antiscia.
/// cantiscia_lon = (antiscia + 180) mod 360 = (-lon) mod 360
double cantisciaLon(double lon) => normalizeDeg(-lon);

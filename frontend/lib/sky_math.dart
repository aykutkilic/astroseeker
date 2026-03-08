import 'dart:math';

const double d2r = pi / 180.0;
const double r2d = 180.0 / pi;

class SkyMath {
  static double getLST(DateTime date, double lonDegrees) {
    double jd = date.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
    double d = jd - 2451545.0;
    double lstHours = (18.697374558 + 24.06570982441908 * d) % 24.0;
    if (lstHours < 0) lstHours += 24.0;
    return (lstHours * 15.0 + lonDegrees) % 360.0 * d2r;
  }

  static List<double> eclipticToEquatorial(double lon, double lat) {
    double epsilon = 23.439281 * d2r;
    double ra = atan2(
      sin(lon) * cos(epsilon) - tan(lat) * sin(epsilon),
      cos(lon),
    );
    double dec = asin(
      sin(lat) * cos(epsilon) + cos(lat) * sin(epsilon) * sin(lon),
    );
    return [ra, dec];
  }

  static List<double> equatorialToHorizontal(
    double ra,
    double dec,
    double userLat,
    double lst,
  ) {
    double ha = lst - ra;
    double alt = asin(
      sin(userLat) * sin(dec) + cos(userLat) * cos(dec) * cos(ha),
    );
    double az = atan2(
      -sin(ha) * cos(dec),
      cos(userLat) * sin(dec) - sin(userLat) * cos(dec) * cos(ha),
    );
    return [alt, az]; // alt, az in radians
  }

  static List<double> eclipticToHorizontal(
    double lon,
    double lat,
    double userLat,
    double lst,
  ) {
    var eq = eclipticToEquatorial(lon, lat);
    return equatorialToHorizontal(eq[0], eq[1], userLat, lst);
  }
}

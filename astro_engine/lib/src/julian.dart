/// Julian Day Number conversion (Meeus Ch. 7).

/// Convert a UTC DateTime to Julian Day Number.
double dateTimeToJD(DateTime dt) {
  int y = dt.year;
  int m = dt.month;
  double d =
      dt.day +
      dt.hour / 24.0 +
      dt.minute / 1440.0 +
      dt.second / 86400.0 +
      dt.millisecond / 86400000.0;

  if (m <= 2) {
    y -= 1;
    m += 12;
  }

  // Gregorian calendar reform
  int a = y ~/ 100;
  int b = 2 - a + a ~/ 4;

  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      d +
      b -
      1524.5;
}

/// Convert Julian Day Number to DateTime (UTC).
DateTime jdToDateTime(double jd) {
  double z0 = jd + 0.5;
  int z = z0.floor();
  double f = z0 - z;

  int a;
  if (z < 2299161) {
    a = z;
  } else {
    int alpha = ((z - 1867216.25) / 36524.25).floor();
    a = z + 1 + alpha - alpha ~/ 4;
  }

  int b = a + 1524;
  int c = ((b - 122.1) / 365.25).floor();
  int d = (365.25 * c).floor();
  int e = ((b - d) / 30.6001).floor();

  double day = b - d - (30.6001 * e).floor() + f;
  int month = e < 14 ? e - 1 : e - 13;
  int year = month > 2 ? c - 4716 : c - 4715;

  int dayInt = day.floor();
  double frac = day - dayInt;
  int hour = (frac * 24).floor();
  frac = frac * 24 - hour;
  int minute = (frac * 60).floor();
  frac = frac * 60 - minute;
  int second = (frac * 60).floor();
  int ms = ((frac * 60 - second) * 1000).round();

  return DateTime.utc(year, month, dayInt, hour, minute, second, ms);
}

/// Julian centuries from J2000.0 (for use in most Meeus formulas).
double julianCenturies(double jd) => (jd - 2451545.0) / 36525.0;

/// Julian millennia from J2000.0 (for VSOP87).
double julianMillennia(double jd) => (jd - 2451545.0) / 365250.0;

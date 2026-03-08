import 'package:test/test.dart';
import 'package:astro_engine/astro_engine.dart';
import 'package:astro_engine/src/julian.dart';

void main() {
  group('Julian Day', () {
    test('J2000.0 epoch', () {
      // J2000.0 = 2000 Jan 1.5 TT = JD 2451545.0
      final jd = dateTimeToJD(DateTime.utc(2000, 1, 1, 12, 0, 0));
      expect(jd, closeTo(2451545.0, 0.0001));
    });

    test('round-trip conversion', () {
      final dt = DateTime.utc(1984, 1, 1, 22, 45);
      final jd = dateTimeToJD(dt);
      final dt2 = jdToDateTime(jd);
      expect(dt2.year, dt.year);
      expect(dt2.month, dt.month);
      expect(dt2.day, dt.day);
      expect(dt2.hour, dt.hour);
      expect(dt2.minute, dt.minute);
    });
  });

  group('NatalChart.calculate', () {
    // Reference: the out.json golden file was computed for:
    // date=? time=? gmt=? lat=41.01 lon=28.58
    // We don't know the exact input time, but we can test a known date.

    test('produces valid structure', () {
      // 1984/01/01 22:45 UTC (approximate)
      final utc = DateTime.utc(1984, 1, 1, 19, 45); // 22:45 local - 3h GMT offset
      final chart = NatalChart.calculate(utc, 41.01, 28.58);

      expect(chart.containsKey('general'), isTrue);
      expect(chart.containsKey('objects'), isTrue);
      expect(chart.containsKey('houses'), isTrue);
      expect(chart.containsKey('angles'), isTrue);
      expect(chart.containsKey('fixedStars'), isTrue);

      final objects = chart['objects'] as Map<String, dynamic>;
      expect(objects.containsKey('Sun'), isTrue);
      expect(objects.containsKey('Moon'), isTrue);
      expect(objects.containsKey('Mercury'), isTrue);
      expect(objects.containsKey('Venus'), isTrue);
      expect(objects.containsKey('Mars'), isTrue);
      expect(objects.containsKey('Jupiter'), isTrue);
      expect(objects.containsKey('Saturn'), isTrue);
      expect(objects.containsKey('North Node'), isTrue);
      expect(objects.containsKey('South Node'), isTrue);
      expect(objects.containsKey('Pars Fortuna'), isTrue);
      expect(objects.containsKey('Syzygy'), isTrue);

      final houses = chart['houses'] as List;
      expect(houses.length, 12);

      final angles = chart['angles'] as Map<String, dynamic>;
      expect(angles.containsKey('Asc'), isTrue);
      expect(angles.containsKey('MC'), isTrue);
      expect(angles.containsKey('Desc'), isTrue);
      expect(angles.containsKey('IC'), isTrue);

      // Verify Sun has expected fields
      final sun = objects['Sun'] as Map<String, dynamic>;
      expect(sun['type'], 'Planet');
      expect(sun.containsKey('lon'), isTrue);
      expect(sun.containsKey('lat'), isTrue);
      expect(sun.containsKey('sign'), isTrue);
      expect(sun.containsKey('signlon'), isTrue);
      expect(sun.containsKey('lonspeed'), isTrue);
      expect(sun.containsKey('latspeed'), isTrue);
      expect(sun.containsKey('orb'), isTrue);
      expect(sun.containsKey('movement'), isTrue);
      expect(sun.containsKey('antiscia'), isTrue);
      expect(sun.containsKey('cantiscia'), isTrue);
    });

    test('Sun position for 2000-01-01 12:00 UTC', () {
      // On J2000.0 epoch, Sun is near 280.5° (Capricorn ~10°)
      final utc = DateTime.utc(2000, 1, 1, 12, 0);
      final chart = NatalChart.calculate(utc, 0, 0);
      final sun = chart['objects']['Sun'];
      final sunLon = sun['lon'] as double;

      // Sun should be around 280.5° on Jan 1, 2000
      expect(sunLon, closeTo(280.5, 1.0));
      expect(sun['sign'], 'Capricorn');
    });

    test('calculateSteps returns correct number of steps', () {
      final utc = DateTime.utc(2024, 6, 15, 12, 0);
      final results = NatalChart.calculateSteps(
        utc: utc, geoLat: 41.01, geoLon: 28.58,
        steps: 5, stepMinutes: 60,
      );
      expect(results.length, 5);
    });
  });

  group('Golden file comparison (out.json reference)', () {
    // The out.json reference has Sun at lon 64.6264 (Gemini 4.6°)
    // This suggests a date around late May / early June.
    // We test that for a known modern date, positions are in the right ballpark.

    test('Sun speed is ~1 degree/day', () {
      final utc = DateTime.utc(2024, 3, 20, 12, 0);
      final chart = NatalChart.calculate(utc, 0, 0);
      final sun = chart['objects']['Sun'];
      final speed = sun['lonspeed'] as double;
      expect(speed, closeTo(1.0, 0.1));
    });

    test('Moon speed is ~12-14 degrees/day', () {
      final utc = DateTime.utc(2024, 3, 20, 12, 0);
      final chart = NatalChart.calculate(utc, 0, 0);
      final moon = chart['objects']['Moon'];
      final speed = moon['lonspeed'] as double;
      expect(speed, greaterThan(10));
      expect(speed, lessThan(16));
    });

    test('Houses sum to 360 degrees', () {
      final utc = DateTime.utc(2024, 6, 15, 12, 0);
      final chart = NatalChart.calculate(utc, 41.01, 28.58);
      final houses = chart['houses'] as List;
      double totalSize = 0;
      for (final h in houses) {
        totalSize += h['size'] as double;
      }
      expect(totalSize, closeTo(360.0, 0.01));
    });

    test('Desc is 180 degrees from Asc', () {
      final utc = DateTime.utc(2024, 6, 15, 12, 0);
      final chart = NatalChart.calculate(utc, 41.01, 28.58);
      final asc = chart['angles']['Asc']['lon'] as double;
      final desc = chart['angles']['Desc']['lon'] as double;
      double diff = (desc - asc).abs();
      if (diff > 180) diff = 360 - diff;
      expect(diff, closeTo(180.0, 0.01));
    });
  });
}

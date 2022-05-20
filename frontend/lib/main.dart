import 'dart:math';
import 'package:astroseeked/natal_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import './astrofont.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Natal Chart',
        home: Scaffold(
            appBar: AppBar(
              title: const Text('Natal Chart'),
            ),
            body: BlocProvider(
              create: (_) => NatalCubit()..loadSampleChartData(),
              child: Container(
                  constraints: const BoxConstraints.expand(),
                  child: InteractiveViewer(
                      child: BlocBuilder<NatalCubit, NatalState>(
                    builder: (context, state) {
                      if (state is NatalStateEmpty) {
                        return const Text('Not selected yet');
                      } else if (state is NatalStateError) {
                        return const Text('ERROR');
                      }
                      return NatalChart(state);
                    },
                  ))),
            )));
  }
}

class NatalChart extends StatelessWidget {
  final dynamic data;
  const NatalChart(this.data, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        size: const Size(500, 500), painter: NatalChartPainter(data));
  }
}

const double pi = 3.1415926535;

class NatalChartPainter extends CustomPainter {
  final spacing = .35;
  final outerWidth = .05;
  final innerWidth = .30;
  double refAngle = .0;
  double outerRadius = .0;
  double midRadius = .0;
  double innerRadius = .0;
  Offset center = const Offset(0, 0);
  double radius = .0;

  final dynamic data;
  NatalChartPainter(this.data) : super();

  double d2r(d) {
    return (-d + refAngle + 180) * pi / 180;
  }

  Offset polar(a, r, center) {
    return Offset(cos(a) * r + center.dx, sin(a) * r + center.dy);
  }

  void paintSymbol(canvas, pos, symbol,
      {color = const Color(0xFF1565C0),
      size = 50.0,
      fontFamily = 'Astrodotbasic',
      weight = FontWeight.normal,
      Offset? p1,
      Offset? p2}) {
    if (fontFamily == 'Astrodotbasic' && !key2letter.containsKey(symbol)) {
      return;
    }

    var text = fontFamily == 'Astrodotbasic' ? key2letter[symbol] : symbol;

    var span = TextSpan(
        style: TextStyle(
            color: color,
            fontSize: size,
            fontFamily: fontFamily,
            fontWeight: weight),
        text: text);
    var tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();

    var symbolCenter = Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2);

    if (p1 != null && p2 != null) {
      var linePaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(p1, p2, linePaint);
    }

    tp.paint(canvas, symbolCenter);
  }

  @override
  void paint(Canvas canvas, Size size) {
    var houses = data.root['houses'];
    refAngle = houses[0]['lon'] as double;
    radius = min(size.width / 2, size.height / 2);
    center = Offset(size.width / 2, size.height / 2);
    var paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    outerRadius = radius * (1 - spacing);
    midRadius = radius * (1 - spacing - outerWidth);
    innerRadius = radius * (1 - spacing - outerWidth - innerWidth);

    canvas.drawColor(Colors.black, BlendMode.color);
    canvas.drawCircle(center, outerRadius, paint);
    canvas.drawCircle(center, midRadius, paint);
    canvas.drawCircle(center, innerRadius, paint);

    for (var i = 0; i < 360; i++) {
      var linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = .5
        ..style = PaintingStyle.stroke;

      var rad = d2r(i);
      var p1 = polar(rad, midRadius, center);
      var p2 = polar(rad, midRadius * .97, center);

      if (i % 30 == 0) {
        p2 = polar(rad, innerRadius, center);
        linePaint.strokeWidth = 1;
      } else if (i % 10 == 0) {
        p2 = polar(rad, midRadius * .89, center);
      } else if (i % 5 == 0) {
        p2 = polar(rad, midRadius * .94, center);
      }

      canvas.drawLine(p1, p2, linePaint);
    }

    for (var i = 0; i < 12; i++) {
      paintSymbol(
          canvas, polar(d2r(i * 30 + 15), midRadius * 0.75, center), signs[i]);
    }

    data.root['angles'].forEach((k, o) {
      var lon = o['lon'];
      var p1 = polar(d2r(lon), midRadius, center);
      var p2 = polar(d2r(lon), midRadius * 1.45, center);
      var size = (k == 'Asc' || k == 'MC') ? 40.0 : 30.0;
      paintSymbol(
          canvas, polar(d2r(lon), midRadius * 1.5, center), k.toLowerCase(),
          color: Colors.black, size: size, p1: p1, p2: p2);
    });

    data.root['objects'].forEach((k, o) {
      var lon = o['lon'];
      var symbolPos = polar(d2r(lon), midRadius * 1.25, center);
      var p1 = polar(d2r(lon), midRadius, center);
      var p2 = polar(d2r(lon), midRadius * 1.15, center);
      var size = (k == 'Sun' || k == 'Moon') ? 50.0 : 40.0;
      paintSymbol(canvas, symbolPos, k.toLowerCase(),
          size: size, p1: p1, p2: p2);
    });

    data.root['houses'].forEach((o) {
      var lon = o['lon'] as double;
      var size = o['size'] as double;
      var num = o['num'];
      var p1 = polar(d2r(lon), midRadius, center);
      var p2 = polar(d2r(lon), outerRadius, center);
      var linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = (num - 1) % 3 == 0 ? 6 : 3
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, linePaint);

      var pos =
          polar(d2r(lon + size / 2), (midRadius + outerRadius) / 2, center);
      paintSymbol(canvas, pos, num.toString(),
          color: Colors.black,
          size: 10.0,
          fontFamily: 'Roboto',
          weight: FontWeight.bold);
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

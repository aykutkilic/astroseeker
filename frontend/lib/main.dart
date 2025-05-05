import 'dart:math';
import 'package:astroseeker/natal_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import './astrofont.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'data.dart';

void main() {
  tzdata.initializeTimeZones();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astro Seeker',
      home: Scaffold(
        appBar: AppBar(title: const Text('Astro Seeker')),
        body: BlocProvider(
          create: (_) => NatalCubit()..loadSampleChartData(),
          child: PageView(
            children: [
              DefaultTabController(
                length: 3,
                initialIndex: 0,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.black,
                      tabs: [
                        Tab(text: 'User Info'),
                        Tab(text: 'Natal Chart'),
                        Tab(text: 'Aspects'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          const UserForm(),
                          Container(
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
                              ),
                            ),
                          ),
                          Container(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserForm extends StatefulWidget {
  const UserForm({super.key});

  @override
  State<StatefulWidget> createState() {
    return UserFormState();
  }
}

class UserFormState extends State<UserForm> {
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  City? _city;

  final _formKey = GlobalKey<FormState>();
  final _typeAheadController = TextEditingController();
  final _dateCtl = TextEditingController();
  final _timeCtl = TextEditingController();

  Widget _buildDate() {
    return TextFormField(
      controller: _dateCtl,
      decoration: const InputDecoration(labelText: 'Date of Birth'),
      onTap: () async {
        FocusScope.of(context).requestFocus(FocusNode());
        _birthDate = await showDatePicker(
          context: context,
          initialDate: _birthDate ?? DateTime(1990),
          firstDate: DateTime(1900),
          lastDate: DateTime(2022),
        );

        if (_birthDate != null) {
          _dateCtl.text =
              '${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}';
        }
      },
    );
    /*return TextButton(
        onPressed: () {
          DatePicker.showDatePicker(context,
              showTitleActions: true,
              minTime: DateTime(1900, 1, 1),
              maxTime: DateTime(2022, 1, 1), onConfirm: (date) {
            _birthDate = date;
          }, currentTime: _birthDate ?? DateTime.now(), locale: LocaleType.en);
        },
        child: Text(
          _birthDate?.toString() ?? 'show date time picker',
          style: const TextStyle(color: Colors.blue),
        ));*/
  }

  Widget _buildTime() {
    return TextFormField(
      controller: _timeCtl,
      decoration: const InputDecoration(labelText: 'Time of Birth'),
      onTap: () async {
        FocusScope.of(context).requestFocus(FocusNode());
        _birthTime = await showTimePicker(
          context: context,
          initialTime: _birthTime ?? TimeOfDay.now(),
        );
        if (_birthTime != null) {
          _timeCtl.text = '${_birthTime!.hour}:${_birthTime!.minute}';
        }
      },
    );
  }

  Widget _buildCity() {
    return TypeAheadField<City>(
      suggestionsCallback: (pattern) async {
        return await BackendService.getCities(pattern.toLowerCase());
      },
      itemBuilder: (context, City city) {
        return ListTile(title: Text(city.name), subtitle: Text(city.country));
      },
      onSelected: (city) {
        _city = city;
        _typeAheadController.text = _city!.name;
      },
      controller: _typeAheadController,
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: DefaultTextStyle.of(
            context,
          ).style.copyWith(fontStyle: FontStyle.italic),
          decoration: const InputDecoration(labelText: 'Birth City'),
          /*validator: (value) {
            if (value == null || value.isEmpty) {
              return 'City must be selected.';
            }

            return null;
          }*/
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(50),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _buildDate(),
            _buildTime(),
            _buildCity(),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState == null ||
                    !_formKey.currentState!.validate()) {
                  return;
                }

                var timeZone = tz.getLocation(_city!.timeZone);

                var gmt = '${timeZone.currentTimeZone.abbreviation}:00';
                var lat = _city!.lat.toString();
                var lon = _city!.lon.toString();

                context.read<NatalCubit>().fetchChartData(
                  _dateCtl.text,
                  _timeCtl.text,
                  gmt,
                  lat,
                  lon,
                );

                DefaultTabController.of(context).animateTo(1);

                _formKey.currentState?.save();
              },
              child: const Text('Download Chart'),
            ),
          ],
        ),
      ),
    );
  }
}

class NatalChart extends StatelessWidget {
  final dynamic data;
  const NatalChart(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(500, 500),
      painter: NatalChartPainter(data),
    );
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

  void paintSymbol(
    canvas,
    pos,
    symbol, {
    color = const Color(0xFF1565C0),
    size = 50.0,
    fontFamily = 'Astrodotbasic',
    weight = FontWeight.normal,
    Offset? p1,
    Offset? p2,
  }) {
    if (fontFamily == 'Astrodotbasic' && !key2letter.containsKey(symbol)) {
      return;
    }

    var text = fontFamily == 'Astrodotbasic' ? key2letter[symbol] : symbol;

    var span = TextSpan(
      style: TextStyle(
        color: color,
        fontSize: size,
        fontFamily: fontFamily,
        fontWeight: weight,
      ),
      text: text,
    );
    var tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    var symbolCenter = Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2);

    if (p1 != null && p2 != null) {
      var linePaint =
          Paint()
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
    var paint =
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

    outerRadius = radius * (1 - spacing);
    midRadius = radius * (1 - spacing - outerWidth);
    innerRadius = radius * (1 - spacing - outerWidth - innerWidth);

    canvas.drawCircle(center, outerRadius, paint);
    canvas.drawCircle(center, midRadius, paint);
    canvas.drawCircle(center, innerRadius, paint);

    for (var i = 0; i < 360; i++) {
      var linePaint =
          Paint()
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
        canvas,
        polar(d2r(i * 30 + 15), midRadius * 0.75, center),
        signs[i],
      );
    }

    data.root['angles'].forEach((k, o) {
      var lon = o['lon'];
      var p1 = polar(d2r(lon), midRadius, center);
      var p2 = polar(d2r(lon), midRadius * 1.45, center);
      var size = (k == 'Asc' || k == 'MC') ? 40.0 : 30.0;
      paintSymbol(
        canvas,
        polar(d2r(lon), midRadius * 1.5, center),
        k.toLowerCase(),
        color: Colors.black,
        size: size,
        p1: p1,
        p2: p2,
      );
    });

    var sortedObjects = data.root['objects'].entries.toList();
    sortedObjects.sort(
      (a, b) => a.value['lon'].compareTo(b.value['lon']) as int,
    );

    double? symLon;

    sortedObjects.forEach((i) {
      var k = i.key;
      var o = i.value;

      var lon = o['lon'];
      symLon = symLon == null ? lon : max(symLon! + 10, lon);
      var symbolPos = polar(d2r(symLon), midRadius * 1.30, center);
      var p1 = polar(d2r(lon), midRadius, center);
      var p2 = polar(d2r(symLon), midRadius * 1.15, center);
      var size = (k == 'Sun' || k == 'Moon') ? 50.0 : 40.0;
      paintSymbol(
        canvas,
        symbolPos,
        k.toLowerCase(),
        size: size,
        p1: p1,
        p2: p2,
      );
    });

    data.root['houses'].forEach((o) {
      var lon = o['lon'] as double;
      var size = o['size'] as double;
      var num = o['num'];
      var p1 = polar(d2r(lon), midRadius, center);
      var p2 = polar(d2r(lon), outerRadius, center);
      var linePaint =
          Paint()
            ..color = Colors.black
            ..strokeWidth = (num - 1) % 3 == 0 ? 6 : 3
            ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, linePaint);

      var pos = polar(
        d2r(lon + size / 2),
        (midRadius + outerRadius) / 2,
        center,
      );
      paintSymbol(
        canvas,
        pos,
        num.toString(),
        color: Colors.black,
        size: 10.0,
        fontFamily: 'Roboto',
        weight: FontWeight.bold,
      );
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

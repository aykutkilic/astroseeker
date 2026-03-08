import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/gestures.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'natal_cubit.dart';
import 'astrofont.dart';

void main() {
  runApp(const AstroSeekerApp());
}

class AstroSeekerApp extends StatelessWidget {
  const AstroSeekerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NatalCubit(),
      child: MaterialApp(
        title: 'Astro Seeker',
        theme: ThemeData.dark().copyWith(
          primaryColor: const Color(0xFF1A237E),
          scaffoldBackgroundColor: const Color(0xFF0D1117),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late DateTime _currentDateTime;
  Timer? _timer;
  int _playbackSpeed = 1;
  bool _isPlaying = false;
  DateTime _lastFetchedTime = DateTime.fromMillisecondsSinceEpoch(0);

  LatLng? _selectedLocation;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _currentDateTime = DateTime.now();
    _loadPersistedData();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _onTick);
  }

  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('lat');
    final lon = prefs.getDouble('lon');
    setState(() {
      if (lat != null && lon != null) {
        _selectedLocation = LatLng(lat, lon);
      } else {
        _selectedLocation = const LatLng(51.5074, -0.1278); // Default London
      }
      _isMapReady = true;
    });
    _fetchChartDataIfNeeded(force: true);
  }

  Future<void> _savePersistedData() async {
    if (_selectedLocation != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('lat', _selectedLocation!.latitude);
      await prefs.setDouble('lon', _selectedLocation!.longitude);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      _selectedLocation = latlng;
    });
    _savePersistedData();
    _fetchChartDataIfNeeded(force: true);
  }

  void _onTick(Timer timer) {
    if (!_isMapReady) return;
    if (_isPlaying) {
      setState(() {
        _currentDateTime = _currentDateTime.add(Duration(milliseconds: 16 * _playbackSpeed));
      });
    }
    _fetchChartDataIfNeeded();
  }

  void _fetchChartDataIfNeeded({bool force = false}) {
    if (!_isMapReady || _selectedLocation == null) return;
    
    if (force || _currentDateTime.difference(_lastFetchedTime).inHours.abs() >= 6) {
      _lastFetchedTime = _currentDateTime;
      final fetchStart = _currentDateTime.subtract(const Duration(hours: 2));
      final dateStr = DateFormat('yyyy/MM/dd').format(fetchStart);
      final timeStr = '${fetchStart.hour.toString().padLeft(2, '0')}:${fetchStart.minute.toString().padLeft(2, '0')}';
      final offset = fetchStart.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final hrs = offset.inHours.abs().toString().padLeft(2, '0');
      final mins = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final gmtStr = '$sign$hrs:$mins';

      context.read<NatalCubit>().fetchChartData(
        fetchStart,
        dateStr,
        timeStr,
        gmtStr,
        _selectedLocation!.latitude.toString(),
        _selectedLocation!.longitude.toString(),
      );
    }
  }

  double _shortestAngleDist(double a0, double a1) {
    double da = (a1 - a0) % 360.0;
    return 2 * da % 360.0 - da;
  }

  double _interpolateAngle(double t, double p0, double p1) {
    return (p0 + t * _shortestAngleDist(p0, p1)) % 360.0;
  }

  Map<String, dynamic> _interpolateData(dynamic rootData, DateTime fetchStart, DateTime currentDateTime) {
    if (rootData is! List) {
      return rootData as Map<String, dynamic>;
    }
    
    final charts = rootData;
    if (charts.isEmpty) return {};
    
    double diffHours = currentDateTime.difference(fetchStart).inMilliseconds / (1000 * 60 * 60);
    
    // Clamp to prevent wild extrapolation when jumping in time or waiting for a slow fetch
    if (diffHours < 1.0) diffHours = 1.0;
    if (diffHours > charts.length - 2.0) diffHours = charts.length - 2.0;
    
    int index = diffHours.floor();
    if (index > charts.length - 2) index = charts.length - 2;
    
    double t = diffHours - index;
    
    var c0 = charts[index] as Map<String, dynamic>;
    var c1 = charts[index + 1] as Map<String, dynamic>;

    final newObjects = <String, dynamic>{};
    (c0['objects'] as Map<String, dynamic>).forEach((key, obj) {
      final newObj = Map<String, dynamic>.from(obj as Map);
      
      double lon0 = (c0['objects'][key]['lon'] as num).toDouble();
      double lon1 = (c1['objects'][key]['lon'] as num).toDouble();
      newObj['lon'] = _interpolateAngle(t, lon0, lon1);

      double lat0 = (c0['objects'][key]['lat'] as num).toDouble();
      double lat1 = (c1['objects'][key]['lat'] as num).toDouble();
      newObj['lat'] = _interpolateAngle(t, lat0, lat1);
      
      newObjects[key] = newObj;
    });

    final newHouses = (c0['houses'] as List<dynamic>).asMap().entries.map((entry) {
      int idx = entry.key;
      final newH = Map<String, dynamic>.from(entry.value as Map);
      
      double lon0 = (c0['houses'][idx]['lon'] as num).toDouble();
      double lon1 = (c1['houses'][idx]['lon'] as num).toDouble();
      
      newH['lon'] = _interpolateAngle(t, lon0, lon1);
      return newH;
    }).toList();

    for (int i = 0; i < newHouses.length; i++) {
      double currentLon = newHouses[i]['lon'];
      double nextLon = newHouses[(i + 1) % newHouses.length]['lon'];
      double size = (nextLon - currentLon) % 360.0;
      if (size < 0) size += 360.0;
      newHouses[i]['size'] = size;
    }

    final newAngles = <String, dynamic>{};
    (c0['angles'] as Map<String, dynamic>).forEach((key, val) {
      final newA = Map<String, dynamic>.from(val as Map);
      double lon0 = (c0['angles'][key]['lon'] as num).toDouble();
      double lon1 = (c1['angles'][key]['lon'] as num).toDouble();
      newA['lon'] = _interpolateAngle(t, lon0, lon1);
      newAngles[key] = newA;
    });

    return {
      ...c0,
      'objects': newObjects,
      'houses': newHouses,
      'angles': newAngles,
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime({int? year, int? month, int? day, int? hour, int? minute, int? second}) {
    setState(() {
      _currentDateTime = DateTime(
        year ?? _currentDateTime.year,
        month ?? _currentDateTime.month,
        day ?? _currentDateTime.day,
        hour ?? _currentDateTime.hour,
        minute ?? _currentDateTime.minute,
        second ?? _currentDateTime.second,
      );
    });
  }

  Widget _buildNumberAdjuster(int value, int padding, Function(int) onChanged) {
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          if (pointerSignal.scrollDelta.dy > 0) {
            onChanged(value - 1); // Scrolled down
          } else if (pointerSignal.scrollDelta.dy < 0) {
            onChanged(value + 1); // Scrolled up
          }
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onChanged(value + 1),
            child: const Icon(Icons.arrow_drop_up, size: 16),
          ),
          Text(value.toString().padLeft(padding, '0'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          InkWell(
            onTap: () => onChanged(value - 1),
            child: const Icon(Icons.arrow_drop_down, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeControls() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withAlpha(200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNumberAdjuster(_currentDateTime.year, 4, (val) => _updateTime(year: val)),
                const Text('-', style: TextStyle(fontSize: 14)),
                _buildNumberAdjuster(_currentDateTime.month, 2, (val) => _updateTime(month: val)),
                const Text('-', style: TextStyle(fontSize: 14)),
                _buildNumberAdjuster(_currentDateTime.day, 2, (val) => _updateTime(day: val)),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent),
                  child: IconButton(
                    iconSize: 18,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    onPressed: () => setState(() => _isPlaying = !_isPlaying),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  iconSize: 18,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.restore),
                  tooltip: 'Back to real time',
                  onPressed: () {
                    setState(() {
                      _currentDateTime = DateTime.now();
                      _isPlaying = false;
                      _playbackSpeed = 1;
                    });
                    _fetchChartDataIfNeeded(force: true);
                  },
                ),
                const SizedBox(width: 8),
                _buildNumberAdjuster(_currentDateTime.hour, 2, (val) => _updateTime(hour: val)),
                const Text(':', style: TextStyle(fontSize: 14)),
                _buildNumberAdjuster(_currentDateTime.minute, 2, (val) => _updateTime(minute: val)),
                const Text(':', style: TextStyle(fontSize: 14)),
                _buildNumberAdjuster(_currentDateTime.second, 2, (val) => _updateTime(second: val)),
              ],
            ),
            const SizedBox(height: 2),
            SegmentedButton<int>(
              style: SegmentedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: const TextStyle(fontSize: 10),
                minimumSize: const Size(0, 24),
              ),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 1, label: Text('1x')),
                ButtonSegment(value: 10, label: Text('10x')),
                ButtonSegment(value: 100, label: Text('100x')),
                ButtonSegment(value: 1000, label: Text('1Kx')),
                ButtonSegment(value: 10000, label: Text('10Kx')),
                ButtonSegment(value: 100000, label: Text('100Kx')),
              ],
              selected: {_playbackSpeed > 100000 ? 100000 : _playbackSpeed},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _playbackSpeed = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Astro Seeker')),
      body: Stack(
        children: [
          BlocBuilder<NatalCubit, NatalState>(
            builder: (context, state) {
              if (state is NatalStateEmpty) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is NatalStateError) {
                return Center(child: Text(state.errorMsg, style: const TextStyle(color: Colors.red)));
              } else if (state is NatalStateLoaded) {
                final interpolatedData = _interpolateData(state.root, state.fetchTime, _currentDateTime);
                return NatalChartView(data: interpolatedData);
              }
              return const SizedBox();
            },
          ),
          if (_isMapReady)
            Positioned(
              bottom: 16,
              left: 16,
              width: 200,
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _selectedLocation ?? const LatLng(51.5, -0.1),
                      initialZoom: 1.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          _onMapTap(TapPosition(const Offset(0, 0), const Offset(0, 0)), position.center);
                        }
                      },
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.astroseeker',
                        tileBuilder: (context, tileWidget, tile) {
                          return ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              -1,  0,  0, 0, 255,
                               0, -1,  0, 0, 255,
                               0,  0, -1, 0, 255,
                               0,  0,  0, 1,   0,
                            ]),
                            child: tileWidget,
                          );
                        },
                      ),
                      if (_selectedLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLocation!,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 24),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildTimeControls(),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Natal Chart View
// ----------------------------------------------------------------------
class NatalChartView extends StatefulWidget {
  final dynamic data;
  const NatalChartView({super.key, required this.data});

  @override
  State<NatalChartView> createState() => _NatalChartViewState();
}

class _NatalChartViewState extends State<NatalChartView> {
  Offset? _hoverPos;
  String? _pinnedKey = 'Asc';
  List<Map<String, dynamic>> _hitZones = [];
  String _geminiApiKey = '';

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiApiKey = prefs.getString('gemini_api_key') ?? '';
    });
  }

  void _showInterpretation(String key) async {
    if (_geminiApiKey.isEmpty) {
      final keyController = TextEditingController();
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enter Gemini API Key'),
          content: TextField(
            controller: keyController,
            decoration: const InputDecoration(hintText: 'AIzaSy...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('gemini_api_key', keyController.text);
                setState(() {
                  _geminiApiKey = keyController.text;
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (_geminiApiKey.isEmpty) return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Consulting the stars...'),
          ],
        ),
      ),
    );

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', // Using standard flash for broader compatibility and speed
        apiKey: _geminiApiKey,
      );
      final prompt = 'Provide a short, insightful astrological interpretation of the symbol/entity: "$key". Keep it under 3 sentences. Do not use markdown.';
      final response = await model.generateContent([Content.text(prompt)]);

      if (context.mounted) {
        Navigator.pop(context); // close loading
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(key.toUpperCase()),
            content: Text(response.text ?? 'No interpretation available.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    for (var zone in _hitZones) {
      if ((event.localPosition - (zone['pos'] as Offset)).distance < 25) {
        if (event.buttons == kSecondaryButton) {
          // Right click pins the chart
          setState(() {
            _pinnedKey = zone['key'];
          });
        } else if (event.buttons == kPrimaryButton) {
          // Left click gets AI info
          _showInterpretation(zone['key']);
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1117),
      child: InteractiveViewer(
        child: Listener(
          onPointerDown: _onPointerDown,
          child: MouseRegion(
            onHover: (event) {
              setState(() { _hoverPos = event.localPosition; });
            },
            onExit: (event) {
              setState(() { _hoverPos = null; });
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: NatalChartPainter(
                widget.data, 
                _hoverPos, 
                _pinnedKey,
                (zones) => _hitZones = zones,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NatalChartPainter extends CustomPainter {
  final spacing = .35;
  final outerWidth = .05;
  final innerWidth = .20;
  double refAngle = .0;
  double outerRadius = .0;
  double midRadius = .0;
  double innerRadius = .0;
  Offset center = const Offset(0, 0);
  double radius = .0;

  final dynamic data;
  final Offset? hoverPos;
  final String? pinnedKey;
  final Function(List<Map<String, dynamic>>) onHitZonesUpdate;
  
  NatalChartPainter(this.data, this.hoverPos, this.pinnedKey, this.onHitZonesUpdate) : super();

  double d2r(d) {
    return (-d + refAngle + 180) * pi / 180;
  }

  Offset polar(a, r, center) {
    return Offset(cos(a) * r + center.dx, sin(a) * r + center.dy);
  }

  void paintSymbol(
    Canvas canvas,
    Offset pos,
    String symbol, {
    Color color = const Color(0xFF1565C0),
    double size = 50.0,
    String fontFamily = 'Astrodotbasic',
    FontWeight weight = FontWeight.normal,
    bool glow = false,
  }) {
    String text = symbol;
    if (fontFamily == 'Astrodotbasic') {
      if (key2letter.containsKey(symbol)) {
        text = key2letter[symbol]!;
      } else {
        fontFamily = 'Roboto';
        size = 14.0;
        text = text.isNotEmpty ? text[0].toUpperCase() + text.substring(1) : text;
      }
    }

    var span = TextSpan(
      style: TextStyle(
        color: color,
        fontSize: size,
        fontFamily: fontFamily,
        fontWeight: weight,
        shadows: glow ? [Shadow(color: color, blurRadius: 15), Shadow(color: color, blurRadius: 5)] : null,
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
    tp.paint(canvas, symbolCenter);
  }

  void _drawTooltip(Canvas canvas, Offset pos, String text) {
    var span = TextSpan(
      style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Roboto'),
      text: text,
    );
    var tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    tp.layout();

    var bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy - 30), width: tp.width + 16, height: tp.height + 8),
      const Radius.circular(8),
    );

    canvas.drawRRect(bgRect, Paint()..color = Colors.black87);
    canvas.drawRRect(bgRect, Paint()..color = Colors.white24..style = PaintingStyle.stroke);

    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - 30 - tp.height / 2));
  }

  double _distToSegment(Offset p, Offset v, Offset w) {
    var l2 = (w.dx - v.dx) * (w.dx - v.dx) + (w.dy - v.dy) * (w.dy - v.dy);
    if (l2 == 0) return (p - v).distance;
    var t = ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2;
    t = max(0.0, min(1.0, t));
    return (p - Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy))).distance;
  }

  @override
  void paint(Canvas canvas, Size size) {
    List<Map<String, dynamic>> hitZones = [];
    var houses = data['houses'];
    
    refAngle = houses[0]['lon'] as double;
    if (pinnedKey != null) {
      if (data['angles'].containsKey(pinnedKey)) {
        refAngle = (data['angles'][pinnedKey]['lon'] as num).toDouble();
      } else if (data['objects'].containsKey(pinnedKey)) {
        refAngle = (data['objects'][pinnedKey]['lon'] as num).toDouble();
      } else if (signs.contains(pinnedKey)) {
        refAngle = signs.indexOf(pinnedKey!) * 30.0;
      } else if (pinnedKey!.startsWith('house_')) {
        int hNum = int.parse(pinnedKey!.split('_')[1]);
        var h = (data['houses'] as List).firstWhere((e) => e['num'] == hNum, orElse: () => data['houses'][0]);
        refAngle = (h['lon'] as num).toDouble();
      }
    }

    radius = min(size.width / 2, size.height / 2);
    center = Offset(size.width / 2, size.height / 2);
    var paint =
        Paint()
          ..color = Colors.white54
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
            ..color = Colors.white54
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

    List<Map<String, dynamic>> tooltips = [];

    for (var i = 0; i < 12; i++) {
      var signPos = polar(d2r(i * 30 + 15), (midRadius + innerRadius) / 2, center);
      bool isHovered = hoverPos != null && (hoverPos! - signPos).distance < 30;
      
      hitZones.add({'key': signs[i], 'pos': signPos});

      if (isHovered) {
        tooltips.add({'text': signs[i].toUpperCase(), 'pos': signPos});
      }

      paintSymbol(
        canvas,
        signPos,
        signs[i],
        color: isHovered ? Colors.white : Colors.white54,
        size: isHovered ? 60.0 : 50.0,
        glow: isHovered,
      );
    }
    // Prepare list of all points for aspects (objects + angles)
    List<Map<String, dynamic>> aspectPoints = [];
    data['objects'].forEach((k, o) {
      aspectPoints.add({'name': k, 'lon': (o['lon'] as num).toDouble()});
    });
    data['angles'].forEach((k, o) {
      aspectPoints.add({'name': k, 'lon': (o['lon'] as num).toDouble()});
    });

    // Draw Aspects (Inner Lines)
    for (int i = 0; i < aspectPoints.length; i++) {
      for (int j = i + 1; j < aspectPoints.length; j++) {
        double lon1 = aspectPoints[i]['lon'];
        double lon2 = aspectPoints[j]['lon'];
        double diff = (lon1 - lon2).abs();
        if (diff > 180) diff = 360 - diff;
        
        Color? aspectColor;
        double strokeWidth = 1.0;
        String aspectName = '';
        
        if ((diff - 180).abs() <= 8) { // Opposition
          aspectColor = Colors.red;
          strokeWidth = 2.0;
          aspectName = 'Opposition';
        } else if ((diff - 90).abs() <= 8) { // Square
          aspectColor = Colors.red;
          strokeWidth = 2.0;
          aspectName = 'Square';
        } else if ((diff - 120).abs() <= 8) { // Trine
          aspectColor = Colors.blue;
          strokeWidth = 1.5;
          aspectName = 'Trine';
        } else if ((diff - 60).abs() <= 6) { // Sextile
          aspectColor = Colors.lightBlueAccent;
          strokeWidth = 1.0;
          aspectName = 'Sextile';
        }
        
        if (aspectColor != null) {
          var pt1 = polar(d2r(lon1), innerRadius, center);
          var pt2 = polar(d2r(lon2), innerRadius, center);
          
          bool isHovered = hoverPos != null && _distToSegment(hoverPos!, pt1, pt2) < 6.0;
          
          if (isHovered) {
            aspectColor = Colors.white;
            strokeWidth += 2.0;
            tooltips.add({
              'text': '${aspectPoints[i]['name']} - ${aspectPoints[j]['name']} ($aspectName)', 
              'pos': hoverPos!
            });
          }
          
          canvas.drawLine(pt1, pt2, Paint()..color = aspectColor.withAlpha(isHovered ? 255 : 150)..strokeWidth = strokeWidth..style = PaintingStyle.stroke);
        }
      }
    }

    data['houses'].forEach((o) {
      var lon = o['lon'] as double;
      var size = o['size'] as double;
      var num = o['num'];
      var p1 = polar(d2r(lon), midRadius, center);
      var p2 = polar(d2r(lon), outerRadius, center);
      var linePaint =
          Paint()
            ..color = Colors.white38
            ..strokeWidth = (num - 1) % 3 == 0 ? 4 : 1
            ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, linePaint);

      var pos = polar(
        d2r(lon + size / 2),
        (midRadius + outerRadius) / 2,
        center,
      );

      hitZones.add({'key': 'house_$num', 'pos': pos});

      bool isHovered = hoverPos != null && (hoverPos! - pos).distance < 20;

      if (isHovered) {
        int deg = (lon % 30).floor();
        int min = (((lon % 30) - deg) * 60).floor();
        tooltips.add({'text': 'House $num ($deg° $min\')', 'pos': pos});
      }

      paintSymbol(
        canvas,
        pos,
        num.toString(),
        color: isHovered ? Colors.white : Colors.white70,
        size: isHovered ? 16.0 : 10.0,
        fontFamily: 'Roboto',
        weight: FontWeight.bold,
        glow: isHovered,
      );
    });

    // Draw Angles
    data['angles'].forEach((k, o) {
      var lon = o['lon'];
      var p1 = polar(d2r(lon), midRadius, center);
      var p2 = polar(d2r(lon), midRadius * 1.45, center);
      var size = (k == 'Asc' || k == 'MC') ? 40.0 : 30.0;
      var symbolPos = polar(d2r(lon), midRadius * 1.5, center);
      
      canvas.drawLine(p1, p2, Paint()..color = Colors.lightBlueAccent.withAlpha(100)..strokeWidth = 2..style = PaintingStyle.stroke);

      hitZones.add({'key': k, 'pos': symbolPos});

      bool isHovered = hoverPos != null && (hoverPos! - symbolPos).distance < 25;

      if (isHovered) {
        int deg = (lon % 30).floor();
        int min = (((lon % 30) - deg) * 60).floor();
        tooltips.add({'text': '$k ($deg° $min\')', 'pos': symbolPos});
      }
      
      paintSymbol(
        canvas,
        symbolPos,
        k.toLowerCase(),
        color: isHovered ? Colors.white : Colors.lightBlueAccent,
        size: isHovered ? size * 1.2 : size,
        glow: isHovered,
      );
    });

    // Object Priorities
    final Map<String, int> objPriority = {
      'Sun': 100, 'Moon': 90, 'Mercury': 80, 'Venus': 70, 'Mars': 60,
      'Jupiter': 50, 'Saturn': 40, 'Uranus': 30, 'Neptune': 20, 'Pluto': 10,
    };

    var sortedObjects = data['objects'].entries.toList();
    sortedObjects.sort((a, b) {
      int pA = objPriority[a.key] ?? 0;
      int pB = objPriority[b.key] ?? 0;
      return pB.compareTo(pA); // Descending priority
    });

    List<Map<String, dynamic>> plotted = [];
    List<Map<String, dynamic>> finalDrawList = [];

    sortedObjects.forEach((i) {
      var k = i.key;
      var o = i.value;

      var rawLon = (o['lon'] as num).toDouble();
      var size = (k == 'Sun' || k == 'Moon') ? 50.0 : 40.0;
      
      double objRadius = outerRadius + size / 2 + 10.0;
      bool overlap = true;
      while (overlap) {
        overlap = false;
        for (var p in plotted) {
          double angleDist = (rawLon - p['lon']).abs();
          if (angleDist > 180) angleDist = 360 - angleDist;
          double radiusDist = (objRadius - p['radius']).abs();
          
          if (angleDist < 5.0 && radiusDist < 30.0) {
            overlap = true;
            objRadius += 30.0;
            break;
          }
        }
      }
      plotted.add({'lon': rawLon, 'radius': objRadius});
      finalDrawList.add({
        'key': k,
        'lon': rawLon,
        'radius': objRadius,
        'size': size,
      });
    });

    // Draw linking lines behind
    for (var item in finalDrawList) {
      var rawLon = item['lon'];
      var objRadius = item['radius'];
      var size = item['size'];
      var p1 = polar(d2r(rawLon), midRadius, center);
      var p2 = polar(d2r(rawLon), objRadius - size / 2 - 5.0, center);
      
      canvas.drawLine(p1, p2, Paint()..color = Colors.amberAccent.withAlpha(100)..strokeWidth = 2..style = PaintingStyle.stroke);
    }

    // Draw object symbols on top
    for (var item in finalDrawList) {
      var k = item['key'];
      var rawLon = item['lon'];
      var objRadius = item['radius'];
      var size = item['size'];
      var symbolPos = polar(d2r(rawLon), objRadius, center);
      
      hitZones.add({'key': k, 'pos': symbolPos});

      bool isHovered = hoverPos != null && (hoverPos! - symbolPos).distance < 25;

      if (isHovered) {
        int deg = (rawLon % 30).floor();
        int min = (((rawLon % 30) - deg) * 60).floor();
        tooltips.add({'text': '$k ($deg° $min\')', 'pos': symbolPos});
      }

      paintSymbol(
        canvas,
        symbolPos,
        k.toLowerCase(),
        size: isHovered ? size * 1.2 : size,
        color: isHovered ? Colors.white : Colors.amberAccent,
        glow: true,
      );
    }

    for (var t in tooltips) {
      _drawTooltip(canvas, t['pos'], t['text']);
    }

    // Schedule sending hit zones back to the widget (avoiding rebuild during paint)
    Future.microtask(() => onHitZonesUpdate(hitZones));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// ----------------------------------------------------------------------

import 'dart:isolate';
import 'package:bloc/bloc.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:astro_engine/astro_engine.dart';

abstract class NatalState {
  const NatalState();
}

class NatalStateEmpty extends NatalState {}

class NatalStateLoaded extends NatalState {
  final dynamic root;
  final DateTime fetchTime;
  NatalStateLoaded(this.root, this.fetchTime) : super();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NatalStateLoaded && other.root == root && other.fetchTime == fetchTime;
  }

  @override
  int get hashCode => root.hashCode ^ fetchTime.hashCode;
}

class NatalStateError extends NatalState {
  final String errorMsg;
  NatalStateError(this.errorMsg) : super();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NatalStateError && other.errorMsg == errorMsg;
  }

  @override
  int get hashCode => errorMsg.hashCode;
}

/// Parameters for the isolate computation.
class _ChartParams {
  final DateTime utc;
  final double lat;
  final double lon;
  final int steps;
  final int stepMinutes;

  _ChartParams(this.utc, this.lat, this.lon, this.steps, this.stepMinutes);
}

/// Top-level function for isolate execution.
List<Map<String, dynamic>> _computeChart(_ChartParams params) {
  return NatalChart.calculateSteps(
    utc: params.utc,
    geoLat: params.lat,
    geoLon: params.lon,
    steps: params.steps,
    stepMinutes: params.stepMinutes,
  );
}

class NatalCubit extends Cubit<NatalState> {
  NatalCubit() : super(NatalStateEmpty());

  void loadSampleChartData() async {
    final string = await rootBundle.loadString('assets/out.json');
    emit(NatalStateLoaded(json.decode(string), DateTime.now()));
  }

  Future<void> fetchChartData(DateTime currentDateTime, String birthDate, String birthTime, String gmt, String lat, String lon) async {
    try {
      // Parse parameters
      final cityLat = double.parse(lat);
      final cityLon = double.parse(lon);

      // Parse the date/time and GMT offset to construct UTC DateTime
      final parts = birthDate.split('/');
      final timeParts = birthTime.split(':');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Parse GMT offset (e.g., "+03:00" or "-05:00")
      final gmtSign = gmt.startsWith('-') ? -1 : 1;
      final gmtParts = gmt.substring(1).split(':');
      final gmtHours = int.parse(gmtParts[0]);
      final gmtMinutes = gmtParts.length > 1 ? int.parse(gmtParts[1]) : 0;
      final offsetMinutes = gmtSign * (gmtHours * 60 + gmtMinutes);

      // Local time → UTC
      final localDt = DateTime(year, month, day, hour, minute);
      final utcDt = localDt.subtract(Duration(minutes: offsetMinutes));

      // Run computation in an isolate to avoid blocking the UI
      final result = await Isolate.run(
        () => _computeChart(_ChartParams(utcDt, cityLat, cityLon, 24, 60)),
      );

      emit(NatalStateLoaded(result, currentDateTime));
    } catch (e) {
      emit(NatalStateError('Chart calculation error: $e'));
    }
  }
}

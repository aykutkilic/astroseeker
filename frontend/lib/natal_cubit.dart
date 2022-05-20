import 'package:bloc/bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

abstract class NatalState {
  const NatalState();
}

class NatalStateEmpty extends NatalState {}

class NatalStateLoaded extends NatalState {
  final dynamic root;
  NatalStateLoaded(this.root) : super();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NatalStateLoaded && other.root == root;
  }

  @override
  int get hashCode => root.hashCode;
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

class NatalCubit extends Cubit<NatalState> {
  NatalCubit() : super(NatalStateEmpty());

  void loadSampleChartData() async {
    final string = await rootBundle.loadString('assets/out.json');
    emit(NatalStateLoaded(json.decode(string)));
  }

  // ../natal?date=1984/01/01&time=22:45&gmt=+03:00&city_lat=41.01&city_lon=28.58
  Future<void> fetchChartData(birthDate, birthTime, gmt, lat, lon) async {
    var uri = Uri.https('backend-lnrbdzx7zq-lm.a.run.app', 'natal', {
      'date': birthDate,
      'time': birthTime,
      'gmt': gmt,
      'city_lat': lat,
      'city_lon': lon
    });

    var response = await http.get(uri);
    if (response.statusCode == 200) {
      emit(NatalStateLoaded(jsonDecode(response.body)));
    } else {
      emit(NatalStateError('Can not fetch'));
    }
  }
}

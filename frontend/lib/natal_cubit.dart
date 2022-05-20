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

  void fetchChartData(birthDate, city) async {
    var uri = Uri.http(
        'localhost:3000', 'natal', {'birthDate': birthDate, 'city': city});

    var response = await http.get(uri);
    if (response.statusCode == 200) {
      emit(NatalStateLoaded(jsonDecode(response.body)));
    } else {
      emit(NatalStateError('Can not fetch'));
    }
  }
}

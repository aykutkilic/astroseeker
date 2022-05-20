import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

// https://backend-lnrbdzx7zq-lm.a.run.app/city?prefix=istan
class BackendService {
  static Future<List<City>> getCities(String query) async {
    if (query.isEmpty || query.length < 3) {
      return Future.value([]);
    }
    var url = Uri.https(
        'backend-lnrbdzx7zq-lm.a.run.app', '/city', {'prefix': query});

    var response = await http.get(url);
    List<City> cities = [];
    if (response.statusCode == 200) {
      Iterable json = convert.jsonDecode(response.body);
      cities = List<City>.from(json.map((model) => City.fromJson(model)));
    }

    return Future.value(cities);
  }
}

class City {
  final String ascii;
  final String name;
  final String country;
  final String timeZone;
  final double lat;
  final double lon;

  City(
      {required this.ascii,
      required this.name,
      required this.country,
      required this.timeZone,
      required this.lat,
      required this.lon});

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      ascii: json['ascii'],
      name: json['name'],
      country: json['country'],
      timeZone: json['timezone'],
      lat: json['lat'],
      lon: json['lon'],
    );
  }
}

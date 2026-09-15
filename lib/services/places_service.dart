import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlacePrediction {
  final String placeId;
  final String description;
  PlacePrediction({required this.placeId, required this.description});
}

class PlaceDetail {
  final String name;
  final String? address;
  final LatLng location;
  PlaceDetail({required this.name, this.address, required this.location});
}

class PlacesService {
  static const String _apiKey = 'AIzaSyA8KcEviMocge0WyWD6HHl6juA8bmknyCk';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  static Future<List<PlacePrediction>> autocomplete(String input) async {
    if (input.trim().isEmpty) return [];
    try {
      final url = Uri.parse('$_baseUrl/autocomplete/json')
          .replace(queryParameters: {
        'input': input,
        'key': _apiKey,
        'language': 'es',
        'components': 'country:mx',
        'types': 'geocode|establishment',
      });
      final res = await http.get(url, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) return [];
      final data = json.decode(res.body);
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') return [];
      final predictions = data['predictions'] as List? ?? [];
      return predictions
          .map((p) => PlacePrediction(
                placeId: p['place_id'] ?? '',
                description: p['description'] ?? '',
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<PlaceDetail?> getPlaceDetail(String placeId) async {
    try {
      final url = Uri.parse('$_baseUrl/details/json')
          .replace(queryParameters: {
        'place_id': placeId,
        'key': _apiKey,
        'language': 'es',
        'fields': 'name,formatted_address,geometry',
      });
      final res = await http.get(url, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body);
      if (data['status'] != 'OK') return null;
      final result = data['result'];
      final loc = result['geometry']?['location'];
      if (loc == null) return null;
      return PlaceDetail(
        name: result['name'] ?? '',
        address: result['formatted_address'],
        location: LatLng(
          (loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble(),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

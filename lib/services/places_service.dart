import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlacePrediction {
  final String placeId;
  final String description;
  final String? secondary;
  PlacePrediction({required this.placeId, required this.description, this.secondary});
}

class PlaceDetail {
  final String name;
  final String? address;
  final LatLng location;
  PlaceDetail({required this.name, this.address, required this.location});
}

/// Busqueda de lugares con Google Places. Prioriza los resultados cercanos al
/// origen y expone el error de Google para poder diagnosticar.
class PlacesService {
  // Llave movil (Android/iOS). La de web es distinta y solo se usa en el portal.
  static const String _apiKey = String.fromEnvironment(
    'PLACES_API_KEY',
    defaultValue: 'AIzaSyA8KcEviMocge0WyWD6HHl6juA8bmknyCk',
  );
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  /// Paquete y huella SHA-1 de la app. Se envian a Google porque la llave esta
  /// restringida a aplicaciones Android y las llamadas REST los requieren.
  static const String paqueteAndroid = 'prozoft.com.vaia';
  static const String sha1Android = '8D4BB32F55BD8255FD5436D335D636F8A1F0F742';

  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        'X-Android-Package': paqueteAndroid,
        'X-Android-Cert': sha1Android,
      };

  /// Ultimo error devuelto por Google (vacio si todo bien).
  static String ultimoError = '';

  static Future<List<PlacePrediction>> autocomplete(
    String input, {
    double? lat,
    double? lng,
  }) async {
    ultimoError = '';
    final q = input.trim();
    if (q.isEmpty) return [];
    try {
      final params = <String, String>{
        'input': q,
        'key': _apiKey,
        'language': 'es',
        'components': 'country:mx',
      };
      // Prioriza resultados cercanos al origen seleccionado.
      if (lat != null && lng != null) {
        params['location'] = '$lat,$lng';
        params['origin'] = '$lat,$lng';
        params['radius'] = '30000';
        params['strictbounds'] = 'false';
      }
      final url = Uri.parse('$_baseUrl/autocomplete/json').replace(queryParameters: params);
      final res = await http.get(url, headers: _headers);
      if (res.statusCode != 200) {
        ultimoError = 'HTTP ${res.statusCode}';
        return [];
      }
      final data = json.decode(res.body) as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        ultimoError = (data['error_message']?.toString().isNotEmpty ?? false)
            ? data['error_message'].toString()
            : status;
        return [];
      }
      final predictions = data['predictions'] as List? ?? [];
      return predictions
          .map((p) => PlacePrediction(
                placeId: p['place_id']?.toString() ?? '',
                description: p['structured_formatting']?['main_text']?.toString() ??
                    p['description']?.toString() ??
                    '',
                secondary: p['structured_formatting']?['secondary_text']?.toString() ??
                    p['description']?.toString(),
              ))
          .where((p) => p.placeId.isNotEmpty)
          .toList();
    } catch (e) {
      ultimoError = e.toString();
      return [];
    }
  }

  static Future<PlaceDetail?> getPlaceDetail(String placeId) async {
    ultimoError = '';
    try {
      final url = Uri.parse('$_baseUrl/details/json').replace(queryParameters: {
        'place_id': placeId,
        'key': _apiKey,
        'language': 'es',
        'fields': 'name,formatted_address,geometry',
      });
      final res = await http.get(url, headers: _headers);
      if (res.statusCode != 200) {
        ultimoError = 'HTTP ${res.statusCode}';
        return null;
      }
      final data = json.decode(res.body) as Map<String, dynamic>;
      if (data['status']?.toString() != 'OK') {
        ultimoError = (data['error_message']?.toString().isNotEmpty ?? false)
            ? data['error_message'].toString()
            : (data['status']?.toString() ?? 'Error');
        return null;
      }
      final result = data['result'];
      final loc = result?['geometry']?['location'];
      if (loc == null) {
        ultimoError = 'Sin coordenadas';
        return null;
      }
      return PlaceDetail(
        name: result['name']?.toString() ?? '',
        address: result['formatted_address']?.toString(),
        location: LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()),
      );
    } catch (e) {
      ultimoError = e.toString();
      return null;
    }
  }
}

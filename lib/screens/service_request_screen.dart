import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/profile_provider.dart';
import '../../providers/ride_provider.dart';

class ServiceRequestScreen extends StatefulWidget {
  final double currentLat;
  final double currentLng;

  const ServiceRequestScreen({super.key, required this.currentLat, required this.currentLng});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _promoCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedFavorito;
  String _selectedTripType = 'URBANO';
  bool _isLoading = false;
  double _estimatedDistance = 0;
  double _estimatedCost = 0;
  LatLng? _originLatLng;
  LatLng? _destinationLatLng;

  final List<String> _tripTypes = ['URBANO', 'INTERURBANO', 'AEROPUERTO'];

  @override
  void initState() {
    super.initState();
    _originLatLng = LatLng(widget.currentLat, widget.currentLng);
    _originController.text = 'Mi ubicacion actual';
    _updateMapMarkers();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  void _updateMapMarkers() {
    _markers.clear();
    if (_originLatLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: _originLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Origen'),
        ),
      );
    }
    if (_destinationLatLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          infoWindow: const InfoWindow(title: 'Destino'),
        ),
      );
    }
    setState(() {});
    if (_originLatLng != null && _destinationLatLng != null) {
      _fitBounds();
      _calculateEstimate();
    } else if (_originLatLng != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_originLatLng!, 15));
    }
  }

  void _fitBounds() {
    if (_originLatLng == null || _destinationLatLng == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _originLatLng!.latitude < _destinationLatLng!.latitude ? _originLatLng!.latitude : _destinationLatLng!.latitude,
        _originLatLng!.longitude < _destinationLatLng!.longitude
            ? _originLatLng!.longitude
            : _destinationLatLng!.longitude,
      ),
      northeast: LatLng(
        _originLatLng!.latitude > _destinationLatLng!.latitude ? _originLatLng!.latitude : _destinationLatLng!.latitude,
        _originLatLng!.longitude > _destinationLatLng!.longitude
            ? _originLatLng!.longitude
            : _destinationLatLng!.longitude,
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  void _calculateEstimate() {
    if (_originLatLng == null || _destinationLatLng == null) return;
    final dist = _calculateDistance(
      _originLatLng!.latitude,
      _originLatLng!.longitude,
      _destinationLatLng!.latitude,
      _destinationLatLng!.longitude,
    );
    setState(() {
      _estimatedDistance = dist;
      _estimatedCost = _calculateCost(dist, _selectedTripType);
    });
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        _sin(dLat / 2) * _sin(dLat / 2) + _cos(_toRad(lat1)) * _cos(_toRad(lat2)) * _sin(dLng / 2) * _sin(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * 3.141592653589793 / 180;
  double _sin(double v) => v - (v * v * v) / 6;
  double _cos(double v) => 1 - (v * v) / 2;
  double _sqrt(double v) => v < 0 ? 0 : v * v;
  double _atan2(double y, double x) => y / x;

  double _calculateCost(double meters, String type) {
    final km = meters / 1000;
    switch (type) {
      case 'URBANO':
        return 8.50 + km * 5.50;
      case 'INTERURBANO':
        return 15.00 + km * 7.50;
      case 'AEROPUERTO':
        return 25.00 + km * 9.50;
      default:
        return 8.50 + km * 5.50;
    }
  }

  void _onMapTap(LatLng pos) {
    if (_destinationLatLng == null) {
      setState(() {
        _destinationLatLng = pos;
        _destinationController.text = 'Destino seleccionado en el mapa';
      });
      _updateMapMarkers();
    }
  }

  void _onFavoriteSelected(String? value) {
    if (value == null) return;
    final profile = context.read<ProfileProvider>();
    final fav = profile.favoritos.where((f) => f.nombre == value).firstOrNull;
    if (fav != null) {
      setState(() {
        _selectedFavorito = value;
        _destinationLatLng = LatLng(double.parse(fav.lat), double.parse(fav.lng));
        _destinationController.text = fav.direccion ?? fav.nombre;
      });
      _updateMapMarkers();
    }
  }

  Future<void> _solicitarServicio() async {
    if (!_formKey.currentState!.validate()) return;
    if (_destinationLatLng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleccione un destino'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    final ride = context.read<RideProvider>();
    final success = await ride.solicitarServicio(
      dirOrigen: _originController.text,
      latOrigen: _originLatLng!.latitude.toString(),
      lngOrigen: _originLatLng!.longitude.toString(),
      dirDestino: _destinationController.text,
      latDestino: _destinationLatLng!.latitude.toString(),
      lngDestino: _destinationLatLng!.longitude.toString(),
      distanciaMetros: _estimatedDistance.round(),
      codigoPromocional: _promoCodeController.text.trim().isEmpty ? null : _promoCodeController.text.trim(),
      tipoviaje: _selectedTripType,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Servicio solicitado correctamente'), backgroundColor: Colors.green));
      Navigator.of(context).pop();
    } else if (ride.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ride.error!), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Solicitar Servicio'), backgroundColor: Colors.white),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _originLatLng ?? LatLng(widget.currentLat, widget.currentLng),
                  zoom: 14,
                ),
                onMapCreated: (ctrl) => _mapController = ctrl,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                onTap: _onMapTap,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _originController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.circle, color: AppTheme.primary),
                        labelText: 'Origen',
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.location_on, color: AppTheme.danger),
                        labelText: 'Destino',
                        hintText: 'Toca el mapa o selecciona un favorito',
                        suffixIcon: _destinationController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _destinationController.clear();
                                    _destinationLatLng = null;
                                    _estimatedDistance = 0;
                                    _estimatedCost = 0;
                                  });
                                  _updateMapMarkers();
                                },
                              )
                            : null,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Seleccione un destino' : null,
                    ),
                    if (profile.favoritos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedFavorito,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.star_outline),
                          labelText: 'Lugares favoritos',
                        ),
                        items: profile.favoritos
                            .map(
                              (f) => DropdownMenuItem(
                                value: f.nombre,
                                child: Text(f.nombre, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: _onFavoriteSelected,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTripType,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.route_outlined),
                        labelText: 'Tipo de viaje',
                      ),
                      items: _tripTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedTripType = v);
                          if (_destinationLatLng != null) _calculateEstimate();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _promoCodeController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                        labelText: 'Codigo promocional (opcional)',
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    if (_estimatedDistance > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.bgLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Distancia', style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(_estimatedDistance / 1000).toStringAsFixed(1)} km',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: AppTheme.border),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Costo estimado', style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${_estimatedCost.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _solicitarServicio,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Solicitar Servicio', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/ride_provider.dart';
import 'service_status_screen.dart';
import 'place_search_screen.dart';

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

  String _selectedTripType = 'URBANO';
  int _selectedPaymentType = 1;
  bool _isLoading = false;
  bool _validatingPromo = false;
  double _estimatedDistance = 0;
  double _estimatedCost = 0;
  double _discount = 0;
  int _estimatedDuration = 0;
  String? _promoMessage;
  bool _promoValid = false;
  LatLng? _originLatLng;
  LatLng? _destinationLatLng;
  bool _isSettingOrigin = false;
  final List<Map<String, dynamic>> _paradas = [];

  final List<String> _tripTypes = ['URBANO', 'INTERURBANO', 'AEROPUERTO'];

  static const Map<int, String> paymentTypes = {
    1: 'Efectivo',
    2: 'Tarjeta de Credito',
    3: 'Tarjeta de Debito',
    4: 'PayPal',
    5: 'Mercado Pago',
    6: 'Transferencia',
  };

  @override
  void initState() {
    super.initState();
    _originLatLng = LatLng(widget.currentLat, widget.currentLng);
    _originController.text = 'Mi ubicacion actual';
    _updateMapMarkers();
    // Tarifas vigentes del servidor (costo minimo, por km y por minuto)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idCompania = context.read<AuthProvider>().idCompania;
      context.read<ProfileProvider>().cargarTarifas(idCompania > 0 ? idCompania : 1);
    });
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
      _markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: _originLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Origen'),
      ));
    }
    if (_destinationLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: const InfoWindow(title: 'Destino'),
      ));
    }
    for (var i = 0; i < _paradas.length; i++) {
      final p = _paradas[i];
      final lat = double.tryParse(p['lat']?.toString() ?? '');
      final lng = double.tryParse(p['lng']?.toString() ?? '');
      if (lat != null && lng != null) {
        _markers.add(Marker(
          markerId: MarkerId('parada_$i'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: 'Parada ${i + 1}: ${p['direccion']}'),
        ));
      }
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
        _originLatLng!.longitude < _destinationLatLng!.longitude ? _originLatLng!.longitude : _destinationLatLng!.longitude,
      ),
      northeast: LatLng(
        _originLatLng!.latitude > _destinationLatLng!.latitude ? _originLatLng!.latitude : _destinationLatLng!.latitude,
        _originLatLng!.longitude > _destinationLatLng!.longitude ? _originLatLng!.longitude : _destinationLatLng!.longitude,
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  void _calculateEstimate() {
    if (_originLatLng == null || _destinationLatLng == null) return;
    final dist = _calculateDistance(
      _originLatLng!.latitude, _originLatLng!.longitude,
      _destinationLatLng!.latitude, _destinationLatLng!.longitude,
    );
    final speedMps = 8.33;
    final duration = (dist / speedMps).round();
    final cost = _calculateCost(dist, _selectedTripType);
    setState(() {
      _estimatedDistance = dist;
      _estimatedDuration = duration;
      _estimatedCost = cost;
      _applyPromo();
    });
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = _sin(dLat / 2) * _sin(dLat / 2) + _cos(_toRad(lat1)) * _cos(_toRad(lat2)) * _sin(dLng / 2) * _sin(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * 3.141592653589793 / 180;
  double _sin(double v) => v - (v * v * v) / 6;
  double _cos(double v) => 1 - (v * v) / 2;
  double _sqrt(double v) => v < 0 ? 0 : v * v;
  double _atan2(double y, double x) => y / x;

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// Costo estimado: usa la tarifa configurada en el servidor
  /// (minimo + por km + por minuto). El costo real se calcula por
  /// tarifa dinamica al finalizar el servicio.
  double _calculateCost(double meters, String type) {
    final km = meters / 1000;
    final minutes = (meters / 8.33) / 60;

    final tarifas = context.read<ProfileProvider>().tarifas;
    if (tarifas.isNotEmpty) {
      final t = tarifas.first;
      final minimo = _toDouble(t['costominimo']);
      final porKm = _toDouble(t['costoporkm']);
      final porMin = _toDouble(t['costoporminuto']);
      if (minimo > 0 || porKm > 0 || porMin > 0) {
        final base = minimo + km * porKm + minutes * porMin;
        return base * _factorTipo(type);
      }
    }

    // Respaldo local mientras llega la configuracion del servidor
    switch (type) {
      case 'URBANO': return 8.50 + km * 5.50;
      case 'INTERURBANO': return 15.00 + km * 7.50;
      case 'AEROPUERTO': return 25.00 + km * 9.50;
      default: return 8.50 + km * 5.50;
    }
  }

  double _factorTipo(String type) {
    switch (type) {
      case 'INTERURBANO': return 1.25;
      case 'AEROPUERTO': return 1.50;
      default: return 1.00;
    }
  }

  void _applyPromo() {
    if (_promoCodeController.text.trim().toUpperCase() == 'TEST') {
      _discount = _estimatedCost >= 20 ? 20 : _estimatedCost;
      _promoMessage = 'Descuento TEST: -\$${_discount.toStringAsFixed(2)}';
      _promoValid = true;
    } else if (_promoCodeController.text.trim().isEmpty) {
      _discount = 0;
      _promoMessage = null;
      _promoValid = false;
    }
  }

  Future<void> _validatePromo() async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _validatingPromo = true);
    if (code.toUpperCase() == 'TEST') {
      _applyPromo();
      setState(() => _validatingPromo = false);
      if (_promoValid) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_promoMessage!), backgroundColor: Colors.green,
        ));
      }
      return;
    }
    final profile = context.read<ProfileProvider>();
    final result = await profile.validarCodigoPromocional(code, _estimatedCost);
    if (!mounted) return;
    if (result != null && result['valido'] == true) {
      _discount = (result['montodescuento'] as num?)?.toDouble() ?? 0;
      _promoMessage = result['mensaje'] as String?;
      _promoValid = true;
    } else {
      _discount = 0;
      _promoMessage = result?['mensaje'] as String? ?? 'Codigo invalido';
      _promoValid = false;
    }
    setState(() => _validatingPromo = false);
  }

  void _onMapTap(LatLng pos) {
    if (_isSettingOrigin) {
      setState(() {
        _originLatLng = pos;
        _originController.text = 'Origen en mapa';
      });
      _updateMapMarkers();
    } else {
      setState(() {
        _destinationLatLng = pos;
        _destinationController.text = 'Destino en mapa';
      });
      _updateMapMarkers();
    }
  }

  void _swapOriginDestination() {
    final tempLatLng = _originLatLng;
    final tempText = _originController.text;
    setState(() {
      _originLatLng = _destinationLatLng;
      _destinationLatLng = tempLatLng;
      _originController.text = _destinationController.text;
      _destinationController.text = tempText;
    });
    _updateMapMarkers();
  }

  void _resetOriginToCurrent() {
    setState(() {
      _originLatLng = LatLng(widget.currentLat, widget.currentLng);
      _originController.text = 'Mi ubicacion actual';
    });
    _updateMapMarkers();
  }

  Future<void> _openPlaceSearch({required bool isOrigin}) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => PlaceSearchScreen(isOrigin: isOrigin)),
    );
    if (result == null) return;
    final latLng = LatLng(result['lat'] as double, result['lng'] as double);
    final text = result['address'] as String? ?? '';
    if (isOrigin) {
      setState(() {
        _originLatLng = latLng;
        _originController.text = text;
      });
    } else {
      setState(() {
        _destinationLatLng = latLng;
        _destinationController.text = text;
      });
    }
    _updateMapMarkers();
  }

  Future<void> _agregarParada() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen(isOrigin: false)),
    );
    if (result == null) return;
    setState(() {
      _paradas.add({
        'direccion': result['address'] ?? 'Parada ${_paradas.length + 1}',
        'lat': (result['lat'] as double).toString(),
        'lng': (result['lng'] as double).toString(),
        'referencia': 'Parada ${_paradas.length + 1}',
      });
    });
    _updateMapMarkers();
  }

  void _eliminarParada(int index) {
    setState(() => _paradas.removeAt(index));
    _updateMapMarkers();
  }

  void _onFavoriteSelected(String? value) {
    if (value == null) return;
    final profile = context.read<ProfileProvider>();
    final fav = profile.favoritos.where((f) => f.nombre == value).firstOrNull;
    if (fav != null) {
      if (_isSettingOrigin) {
        setState(() {
          _originLatLng = LatLng(double.parse(fav.lat), double.parse(fav.lng));
          _originController.text = fav.direccion ?? fav.nombre;
        });
      } else {
        setState(() {
          _destinationLatLng = LatLng(double.parse(fav.lat), double.parse(fav.lng));
          _destinationController.text = fav.direccion ?? fav.nombre;
        });
      }
      _updateMapMarkers();
    }
  }

  Future<void> _solicitarServicio() async {
    if (!_formKey.currentState!.validate()) return;
    if (_originLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un origen'), backgroundColor: Colors.red));
      return;
    }
    if (_destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un destino'), backgroundColor: Colors.red));
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
      idTipoPago: _selectedPaymentType,
      codigoPromocional: _promoCodeController.text.trim().isEmpty ? null : _promoCodeController.text.trim(),
      tipoviaje: _selectedTripType,
      paradas: List<Map<String, dynamic>>.from(_paradas),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio solicitado correctamente'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ServiceStatusScreen()),
        (route) => false,
      );
    } else if (ride.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ride.error!), backgroundColor: AppTheme.danger),
      );
    }
  }

  String _formatDuration(int seconds) {
    final min = (seconds / 60).ceil();
    if (min < 60) return '$min min';
    return '${min ~/ 60}h ${min % 60}min';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final finalCost = _estimatedCost - _discount;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Solicitar Servicio'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Intercambiar origen/destino',
            onPressed: _swapOriginDestination,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            SizedBox(
              height: 250,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _originLatLng ?? LatLng(widget.currentLat, widget.currentLng),
                  zoom: 14,
                ),
                onMapCreated: (ctrl) => _mapController = ctrl,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onTap: _onMapTap,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: (_isSettingOrigin ? AppTheme.primary : AppTheme.danger).withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(_isSettingOrigin ? Icons.circle : Icons.location_on, size: 16,
                      color: _isSettingOrigin ? AppTheme.primary : AppTheme.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _isSettingOrigin ? 'Toca el mapa para marcar ORIGEN' : 'Toca el mapa para marcar DESTINO',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: _isSettingOrigin ? AppTheme.primary : AppTheme.danger),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isSettingOrigin = !_isSettingOrigin),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary, borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isSettingOrigin ? 'Destino' : 'Origen',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
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
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.circle, color: AppTheme.primary),
                        labelText: 'Origen',
                        hintText: 'Donde te recogemos?',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.search, size: 20),
                              tooltip: 'Buscar direccion',
                              onPressed: () => _openPlaceSearch(isOrigin: true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.my_location, size: 18),
                              tooltip: 'Mi ubicacion',
                              onPressed: _resetOriginToCurrent,
                            ),
                          ],
                        ),
                      ),
                      readOnly: true,
                      onTap: () => _openPlaceSearch(isOrigin: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.location_on, color: AppTheme.danger),
                        labelText: 'Destino',
                        hintText: 'A donde vamos?',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_destinationController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _destinationController.clear();
                                    _destinationLatLng = null;
                                    _estimatedDistance = 0;
                                    _estimatedCost = 0;
                                    _discount = 0;
                                    _promoMessage = null;
                                    _promoValid = false;
                                  });
                                  _updateMapMarkers();
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.search, size: 20),
                              tooltip: 'Buscar destino',
                              onPressed: () => _openPlaceSearch(isOrigin: false),
                            ),
                          ],
                        ),
                      ),
                      readOnly: true,
                      onTap: () => _openPlaceSearch(isOrigin: false),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Seleccione un destino' : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _agregarParada,
                            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                            label: Text(_paradas.isEmpty ? 'Agregar parada intermedia' : 'Agregar otra parada'),
                          ),
                        ),
                      ],
                    ),
                    if (_paradas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.alt_route, size: 16, color: Colors.orange.shade800),
                                const SizedBox(width: 6),
                                Text('${_paradas.length} parada(s) intermedia(s)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade900)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ..._paradas.asMap().entries.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 11,
                                    backgroundColor: Colors.orange.shade700,
                                    child: Text('${e.key + 1}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(e.value['direccion']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _eliminarParada(e.key),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],
                    if (profile.favoritos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.star_outline),
                          labelText: 'Favoritos',
                        ),
                        items: profile.favoritos
                            .map((f) => DropdownMenuItem(value: f.nombre, child: Text(f.nombre, overflow: TextOverflow.ellipsis)))
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
                    DropdownButtonFormField<int>(
                      initialValue: _selectedPaymentType,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.payments_outlined),
                        labelText: 'Metodo de pago',
                      ),
                      items: paymentTypes.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedPaymentType = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _promoCodeController,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.confirmation_number_outlined),
                              labelText: 'Codigo promocional',
                              hintText: 'TEST = -\$20',
                            ),
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setState(() { _applyPromo(); }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _validatingPromo ? null : _validatePromo,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: _validatingPromo
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Validar'),
                        ),
                      ],
                    ),
                    if (_promoMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _promoMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _promoValid ? Colors.green : AppTheme.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (_estimatedDistance > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                        ),
                        child: Column(
                          children: [
                            _detailRow(Icons.straighten, 'Distancia total', '${(_estimatedDistance / 1000).toStringAsFixed(1)} km'),
                            const Divider(height: 20),
                            _detailRow(Icons.timer_outlined, 'Tiempo estimado', _formatDuration(_estimatedDuration)),
                            const Divider(height: 20),
                            _detailRow(Icons.attach_money, 'Tarifa base', '\$8.50'),
                            const Divider(height: 20),
                            _detailRow(Icons.speed, 'Costo por km', '\$5.50/km'),
                            if (_discount > 0) ...[
                              const Divider(height: 20),
                              _detailRow(Icons.discount_outlined, 'Descuento', '-\$${_discount.toStringAsFixed(2)}',
                                  valueColor: Colors.green),
                            ],
                            const Divider(height: 20),
                            Row(
                              children: [
                                Icon(Icons.receipt_long, size: 18, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Text('Total estimado', style: TextStyle(fontSize: 14, color: AppTheme.textMedium)),
                                const Spacer(),
                                Text(
                                  '\$${finalCost.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: AppTheme.textLight),
                          const SizedBox(width: 4),
                          Text(
                            'Pago: ${paymentTypes[_selectedPaymentType] ?? "Efectivo"}',
                            style: TextStyle(fontSize: 12, color: AppTheme.textLight),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _solicitarServicio,
                        child: _isLoading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                'Solicitar Servicio${finalCost > 0 ? " - \$${finalCost.toStringAsFixed(2)}" : ""}',
                                style: const TextStyle(fontSize: 16),
                              ),
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

  Widget _detailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textMedium),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textMedium)),
        const Spacer(),
        Text(value, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: valueColor ?? AppTheme.textDark,
        )),
      ],
    );
  }
}

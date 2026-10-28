import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/ride_provider.dart';
import '../../services/directions_service.dart';
import '../../services/marker_icons.dart';
import '../../services/api_service.dart';
import '../../models/favorito_model.dart';
import '../../config/favorito_categorias.dart';
import 'service_status_screen.dart';
import 'place_search_screen.dart';
import 'travel_preferences_screen.dart';

class ServiceRequestScreen extends StatefulWidget {
  final double currentLat;
  final double currentLng;
  final String? destino;
  final double? destinoLat;
  final double? destinoLng;
  final List<Map<String, dynamic>> paradas;

  const ServiceRequestScreen({
    super.key,
    required this.currentLat,
    required this.currentLng,
    this.destino,
    this.destinoLat,
    this.destinoLng,
    this.paradas = const [],
  });

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

  String _selectedTripType = 'Basico';
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
  final Set<Polyline> _polylines = {};

  final List<String> _tripTypes = ['Basico', 'Plus', 'VIP'];

  // Metodos habilitados por el administrador. Efectivo siempre disponible;
  // PayPal y Mercado Pago se agregan solo si estan activos en la compania.
  Map<int, String> _metodosPago = {1: 'Efectivo'};

  @override
  void initState() {
    super.initState();
    _originLatLng = LatLng(widget.currentLat, widget.currentLng);
    _originController.text = 'Mi ubicacion actual';
    if (widget.destinoLat != null && widget.destinoLng != null) {
      _destinationLatLng = LatLng(widget.destinoLat!, widget.destinoLng!);
      _destinationController.text = (widget.destino != null && widget.destino!.trim().isNotEmpty)
          ? widget.destino!
          : 'Destino';
    }
    if (widget.paradas.isNotEmpty) {
      for (var i = 0; i < widget.paradas.length; i++) {
        final p = Map<String, dynamic>.from(widget.paradas[i]);
        p['id'] = p['id'] ?? 'ini-$i-${DateTime.now().microsecondsSinceEpoch}';
        _paradas.add(p);
      }
    }
    _updateMapMarkers();
    if (_destinationLatLng != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _destinationLatLng != null && _originLatLng != null) {
          _calculateEstimate();
        }
      });
    }
    MarkerIcons.cargar().then((_) { if (mounted) _updateMapMarkers(); });
    // Tarifas vigentes del servidor (costo minimo, por km y por minuto)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idCompania = context.read<AuthProvider>().idCompania;
      context.read<ProfileProvider>().cargarTarifas(idCompania > 0 ? idCompania : 1);
      context.read<ProfileProvider>().cargarPreferenciasViaje();
      _cargarMetodosPago();
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
        icon: MarkerIcons.origin ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'Origen'),
      ));
    }
    if (_destinationLatLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLatLng!,
        icon: MarkerIcons.destination ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        anchor: const Offset(0.5, 0.5),
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

  Future<void> _calculateEstimate() async {
    if (_originLatLng == null || _destinationLatLng == null) return;

    // Respaldo inmediato en linea recta mientras responde Google.
    final distRecta = _calculateDistance(
      _originLatLng!.latitude, _originLatLng!.longitude,
      _destinationLatLng!.latitude, _destinationLatLng!.longitude,
    );
    setState(() {
      _estimatedDistance = distRecta;
      _estimatedDuration = (distRecta / 8.33).round();
      _estimatedCost = _calculateCost(distRecta, _selectedTripType);
      _applyPromo();
    });

    // Ruta real por calles (polilinea + distancia + tiempo) con Google.
    final paradas = _paradas
        .map((p) => LatLng(
              double.tryParse(p['lat']?.toString() ?? '') ?? 0,
              double.tryParse(p['lng']?.toString() ?? '') ?? 0,
            ))
        .where((p) => p.latitude != 0 && p.longitude != 0)
        .toList();
    final ruta = await DirectionsService.ruta(
      origen: _originLatLng!,
      destino: _destinationLatLng!,
      paradas: paradas,
    );
    if (!mounted || ruta == null) return;
    setState(() {
      _polylines
        ..clear()
        ..add(Polyline(
          polylineId: const PolylineId('ruta'),
          points: ruta.puntos,
          color: VaiaColors.primary,
          width: 5,
        ));
      _estimatedDistance = ruta.distanciaMetros.toDouble();
      _estimatedDuration = ruta.duracionSegundos;
      _estimatedCost = _calculateCost(_estimatedDistance, _selectedTripType);
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
    return 8.50 + km * 5.50 + minutes * 1.20;
  }

  // Los tipos de viaje (Basico/Plus/VIP) no cambian la tarifa; solo determinan
  // que gama de unidad puede tomar el servicio.
  double _factorTipo(String type) => 1.00;

  /// Carga los metodos de pago habilitados por el administrador y el metodo
  /// predeterminado del pasajero.
  Future<void> _cargarMetodosPago() async {
    try {
      final auth = context.read<AuthProvider>();
      final api = context.read<ApiService>();
      final cfg = await api.configuracionPago();
      final pref = await api.obtenerPreferenciaPago(auth.userId);
      final m = <int, String>{1: 'Efectivo'};
      bool act(dynamic v) => v == true || v == 1 || v.toString() == '1' || v.toString() == 'true';
      if (cfg.success && cfg.list != null && cfg.list!.isNotEmpty) {
        final c = Map<String, dynamic>.from(cfg.list!.first as Map);
        if (act(c['paypalactivo'])) m[4] = 'PayPal';
        if (act(c['mercadopagoactivo'])) m[5] = 'Mercado Pago';
      }
      int prefId = 1;
      if (pref.success && pref.list != null && pref.list!.isNotEmpty) {
        final p = Map<String, dynamic>.from(pref.list!.first as Map);
        prefId = int.tryParse(p['idtipopagopreferido']?.toString() ?? '0') ?? 0;
      }
      if (!m.containsKey(prefId)) prefId = m.keys.first;
      if (mounted) setState(() { _metodosPago = m; _selectedPaymentType = prefId; });
    } catch (_) {}
  }

  /// Verifica que haya unidades de la gama seleccionada cerca. Si no hay,
  /// sugiere cambiar a otro tipo de viaje disponible.
  Future<bool> _verificarGamaDisponible() async {
    try {
      final api = context.read<ApiService>();
      final resp = await api.gamasDisponibles(_originLatLng!.latitude.toString(), _originLatLng!.longitude.toString());
      if (!resp.success || resp.list == null || resp.list!.isEmpty) return true;
      final lista = resp.list!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      int disp(String nombre) {
        for (final g in lista) {
          if (g['nombre']?.toString().toLowerCase() == nombre.toLowerCase()) {
            return int.tryParse(g['conductores']?.toString() ?? '0') ?? 0;
          }
        }
        return 0;
      }
      if (disp(_selectedTripType) > 0) return true;
      final alternativas = lista.where((g) => (int.tryParse(g['conductores']?.toString() ?? '0') ?? 0) > 0).toList();
      if (alternativas.isEmpty) return true;
      if (!mounted) return true;
      final elegido = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
          title: const Text('Sin unidades de este tipo'),
          content: Text('No hay unidades de tipo "$_selectedTripType" cerca de ti. Puedes cambiar a otro tipo de viaje:'),
          actions: [
            ...alternativas.map((g) => TextButton(
                  onPressed: () => Navigator.pop(ctx, g['nombre'].toString()),
                  child: Text('${g['nombre']} (${g['conductores']})'),
                )),
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
          ],
        ),
      );
      if (elegido != null && mounted) {
        setState(() => _selectedTripType = elegido);
        return true;
      }
      return false;
    } catch (_) {
      return true;
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
    final result = await showPlaceSearchSheet(
      context,
      titulo: isOrigin ? 'Buscar origen' : 'Buscar destino',
      icono: isOrigin ? Icons.trip_origin : Icons.location_on,
      lat: isOrigin ? widget.currentLat : (_originLatLng?.latitude ?? widget.currentLat),
      lng: isOrigin ? widget.currentLng : (_originLatLng?.longitude ?? widget.currentLng),
    );
    if (result == null) return;
    if (result['useMap'] == true) {
      setState(() => _isSettingOrigin = isOrigin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isOrigin ? 'Toca el mapa para marcar el origen' : 'Toca el mapa para marcar el destino'),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 2),
        ));
      }
      return;
    }
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
    final result = await showPlaceSearchSheet(
      context,
      titulo: 'Buscar parada ${_paradas.length + 1}',
      icono: Icons.place_rounded,
      permitirMapa: false,
      lat: _originLatLng?.latitude ?? widget.currentLat,
      lng: _originLatLng?.longitude ?? widget.currentLng,
    );
    if (result == null || result['useMap'] == true) return;
    setState(() {
      _paradas.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
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

  void _onFavoriteSelected(FavoritoModel fav) {
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
    if (_destinationLatLng != null && _originLatLng != null) _calculateEstimate();
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

    final profile = context.read<ProfileProvider>();
    await profile.cargarPreferenciasViaje();
    if (!mounted) return;
    if (!profile.preferencias.configurado) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const TravelPreferencesScreen(onboarding: true)),
      );
      if (!mounted || ok != true) return;
    }

    setState(() => _isLoading = true);
    final ride = context.read<RideProvider>();

    // Antes de solicitar, verifica que existan conductores conectados en el
    // rango configurado. Si no hay, no se permite continuar.
    await ride.buscarConductores(
      lat: _originLatLng!.latitude.toString(),
      lng: _originLatLng!.longitude.toString(),
    );
    if (!mounted) return;
    if (ride.conductoresDisponibles.isEmpty) {
      setState(() => _isLoading = false);
      await _sinConductores();
      return;
    }

    // Si no hay unidades de la gama seleccionada, sugiere cambiar de tipo.
    if (!await _verificarGamaDisponible()) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

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

  /// Aviso cuando no hay conductores conectados en la zona del pasajero.
  Future<void> _sinConductores() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.no_transfer_rounded, color: AppTheme.danger, size: 40),
        title: const Text('Sin conductores cercanos'),
        content: const Text(
            'No hay conductores conectados en tu zona en este momento, por lo que no es posible brindar el servicio. '
            'Intenta de nuevo en unos minutos o muevete a otra ubicacion.'),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
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
    final tieneConfig = _destinationController.text.trim().isNotEmpty || _paradas.isNotEmpty;
    final tarifa = profile.tarifas.isNotEmpty ? profile.tarifas.first : null;
    final tarifaMinima = _toDouble(tarifa?['costominimo']);
    final tarifaKm = _toDouble(tarifa?['costoporkm']);
    final tarifaMinuto = _toDouble(tarifa?['costoporminuto']);

    return PopScope(
      canPop: !tieneConfig,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final salir = await _confirmarSalidaServicio();
        if (salir == true && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
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
                polylines: _polylines,
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Ruta: linea de tiempo vertical animada ───
                    _TimelineRuta(
                      origen: _originController.text,
                      destino: _destinationController.text,
                      paradas: _paradas,
                      onOrigen: () => _openPlaceSearch(isOrigin: true),
                      onDestino: () => _openPlaceSearch(isOrigin: false),
                      onMiUbicacion: _resetOriginToCurrent,
                      onLimpiarDestino: () {
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
                      onAgregarParada: _agregarParada,
                      onEliminarParada: _eliminarParada,
                      onReorderParadas: (nuevas) {
                        setState(() {
                          _paradas
                            ..clear()
                            ..addAll(nuevas);
                        });
                        _updateMapMarkers();
                      },
                    ),
                    if (profile.favoritos.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(children: [
                        const Icon(Icons.star_rounded, size: 16, color: AppTheme.accent),
                        const SizedBox(width: 6),
                        Text('Favoritos',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.textDark.withValues(alpha: 0.8))),
                      ]),
                      const SizedBox(height: 8),
                      _FavoritosRapidos(
                        favoritos: profile.favoritos,
                        onSelect: _onFavoriteSelected,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.route_outlined, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text('Tipo de viaje',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.textDark.withValues(alpha: 0.8))),
                    ]),
                    const SizedBox(height: 8),
                    _TipoViajeSelector(
                      tipos: _tripTypes,
                      seleccionado: _selectedTripType,
                      onSelect: (t) {
                        setState(() => _selectedTripType = t);
                        if (_destinationLatLng != null) _calculateEstimate();
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text('Metodo de pago',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.textDark.withValues(alpha: 0.8))),
                    ]),
                    const SizedBox(height: 8),
                    _MetodosPagoSelector(
                      metodos: _metodosPago,
                      seleccionado: _selectedPaymentType,
                      onSelect: (id) => setState(() => _selectedPaymentType = id),
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
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.receipt_long_rounded, size: 19, color: AppTheme.primary),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Resumen del costo', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                                      Text('Calculado con la tarifa vigente de tu ciudad',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textMedium)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: _costoMini(Icons.route_rounded, 'Distancia', '${(_estimatedDistance / 1000).toStringAsFixed(1)} km')),
                              const SizedBox(width: 8),
                              Expanded(child: _costoMini(Icons.schedule_rounded, 'Tiempo estimado', _formatDuration(_estimatedDuration))),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: _costoMini(Icons.flag_rounded, 'Tarifa minima', '\$${tarifaMinima.toStringAsFixed(2)}')),
                              const SizedBox(width: 8),
                              Expanded(child: _costoMini(Icons.speed_rounded, 'Costo por km', '\$${tarifaKm.toStringAsFixed(2)}')),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: _costoMini(Icons.timer_outlined, 'Costo por minuto', '\$${tarifaMinuto.toStringAsFixed(2)}')),
                              const SizedBox(width: 8),
                              Expanded(child: _costoMini(Icons.account_balance_wallet_rounded, 'Forma de pago', _metodosPago[_selectedPaymentType] ?? 'Efectivo')),
                            ]),
                            if (_discount > 0) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.discount_rounded, size: 17, color: Colors.green),
                                  const SizedBox(width: 8),
                                  const Text('Descuento aplicado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
                                  const Spacer(),
                                  Text('-\$${_discount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.green)),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total estimado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                                        Text('El monto final puede variar por trafico o cambios de ruta.',
                                            style: TextStyle(fontSize: 10.5, color: AppTheme.textMedium)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '\$${finalCost.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primary, letterSpacing: -0.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 13, color: AppTheme.textLight),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text('El cobro se calcula con la distancia y el tiempo reales del servicio.',
                                      style: TextStyle(fontSize: 10.5, color: AppTheme.textLight)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _SlideToConfirm(
                      enabled: !_isLoading,
                      loading: _isLoading,
                      label: 'Desliza para solicitar${finalCost > 0 ? "  \$${finalCost.toStringAsFixed(2)}" : ""}',
                      onConfirm: _solicitarServicio,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<bool?> _confirmarSalidaServicio() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 38),
        title: const Text('Descartar configuracion'),
        content: const Text(
          'Si sales ahora perderas lo que configuraste del servicio (origen, destino, paradas, tipo de viaje y metodo de pago).',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar aqui')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  Widget _costoMini(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: AppTheme.primary),
            const SizedBox(width: 4),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppTheme.textMedium))),
          ]),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
        ],
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

/// Linea de tiempo vertical y animada de la ruta. Se muestra el destino
/// arriba, las paradas al centro y el origen abajo, de modo que el recorrido
/// "avanza hacia lo alto". Un punto luminoso viaja por el riel animando la ruta.
class _TimelineRuta extends StatefulWidget {
  final String origen;
  final String destino;
  final List<Map<String, dynamic>> paradas;
  final VoidCallback onOrigen;
  final VoidCallback onDestino;
  final VoidCallback onMiUbicacion;
  final VoidCallback onLimpiarDestino;
  final VoidCallback onAgregarParada;
  final void Function(int) onEliminarParada;
  final void Function(List<Map<String, dynamic>>) onReorderParadas;
  const _TimelineRuta({
    required this.origen,
    required this.destino,
    required this.paradas,
    required this.onOrigen,
    required this.onDestino,
    required this.onMiUbicacion,
    required this.onLimpiarDestino,
    required this.onAgregarParada,
    required this.onEliminarParada,
    required this.onReorderParadas,
  });

  @override
  State<_TimelineRuta> createState() => _TimelineRutaState();
}

class _TimelineRutaState extends State<_TimelineRuta> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinoNode = _nodo(
      icono: Icons.flag_rounded,
      color: AppTheme.danger,
      titulo: 'Destino',
      valor: widget.destino.isEmpty ? 'A donde vamos?' : widget.destino,
      placeholder: widget.destino.isEmpty,
      onTap: widget.onDestino,
      trailing: widget.destino.isEmpty
          ? null
          : IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: widget.onLimpiarDestino),
    );
    final origenNode = _nodo(
      icono: Icons.my_location_rounded,
      color: AppTheme.primary,
      titulo: 'Origen',
      valor: widget.origen.isEmpty ? 'Donde te recogemos?' : widget.origen,
      onTap: widget.onOrigen,
      trailing: IconButton(icon: const Icon(Icons.my_location, size: 18), onPressed: widget.onMiUbicacion),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Positioned(left: 15, top: 12, bottom: 12, width: 4, child: _riel()),
              Column(children: [
                destinoNode,
                if (widget.paradas.isNotEmpty) _listaParadas(),
                origenNode,
              ]),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onAgregarParada,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(widget.paradas.isEmpty ? 'Agregar parada' : 'Agregar otra parada'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _riel() {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppTheme.primary, AppTheme.accent, AppTheme.danger],
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Align(
            alignment: Alignment(0, 1 - 2 * _c.value),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 2),
                boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.7), blurRadius: 8, spreadRadius: 1)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _listaParadas() {
    final disp = widget.paradas.reversed.toList();
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldP, newP) {
        if (newP > oldP) newP--;
        final it = disp.removeAt(oldP);
        disp.insert(newP, it);
        widget.onReorderParadas(disp.reversed.toList());
      },
      children: [
        for (var i = 0; i < disp.length; i++) _paradaNode(disp[i], i),
      ],
    );
  }

  Widget _paradaNode(Map<String, dynamic> p, int i) {
    final numero = widget.paradas.length - i;
    return _nodo(
      key: ValueKey(p['id'] ?? 'parada_$i'),
      icono: Icons.circle,
      color: AppTheme.accent,
      titulo: 'Parada $numero',
      valor: (p['direccion'] ?? '').toString(),
      onTap: null,
      numero: numero,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: i,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.drag_indicator_rounded, size: 18, color: AppTheme.textMuted),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => widget.onEliminarParada(widget.paradas.length - 1 - i),
          ),
        ],
      ),
    );
  }

  Widget _nodo({
    Key? key,
    required IconData icono,
    required Color color,
    required String titulo,
    required String valor,
    required VoidCallback? onTap,
    required Widget? trailing,
    bool placeholder = false,
    int? numero,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Center(
                    child: numero != null
                        ? Text('$numero', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))
                        : Icon(icono, size: 12, color: color),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
                  const SizedBox(height: 1),
                  Text(
                    valor,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: placeholder ? AppTheme.textMuted : AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}

/// Carrusel horizontal de lugares favoritos con su icono de categoria.
class _FavoritosRapidos extends StatelessWidget {
  final List<FavoritoModel> favoritos;
  final void Function(FavoritoModel) onSelect;
  const _FavoritosRapidos({required this.favoritos, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: favoritos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = favoritos[i];
          final cat = categoriaDe(f.categoria);
          return InkWell(
            onTap: () => onSelect(f),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 168,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cat.color.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.18), shape: BoxShape.circle),
                      child: Icon(cat.icono, size: 14, color: cat.color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f.nombre,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(f.direccion ?? 'Sin direccion',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMedium),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Selector de metodo de pago en tarjetas con icono y color de cada marca.
class _MetodosPagoSelector extends StatelessWidget {
  final Map<int, String> metodos;
  final int seleccionado;
  final void Function(int) onSelect;
  const _MetodosPagoSelector({required this.metodos, required this.seleccionado, required this.onSelect});

  (IconData, Color) _info(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('paypal')) return (Icons.account_balance_wallet_rounded, const Color(0xFF003087));
    if (n.contains('mercado')) return (Icons.payments_rounded, const Color(0xFF009EE3));
    if (n.contains('efectivo')) return (Icons.attach_money_rounded, const Color(0xFF16A34A));
    return (Icons.credit_card_rounded, AppTheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    final entries = metodos.entries.toList();
    return Row(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _card(entries[i].key, entries[i].value)),
        ],
      ],
    );
  }

  Widget _card(int id, String nombre) {
    final (icon, color) = _info(nombre);
    final sel = id == seleccionado;
    return InkWell(
      onTap: () => onSelect(id),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? color : AppTheme.border, width: sel ? 1.6 : 1),
          boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))] : null,
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: color),
                ),
                if (sel)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(nombre,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sel ? color : AppTheme.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Selector de tipo de viaje (Basico / Plus / VIP) en tarjetas.
class _TipoViajeSelector extends StatelessWidget {
  final List<String> tipos;
  final String seleccionado;
  final void Function(String) onSelect;
  const _TipoViajeSelector({required this.tipos, required this.seleccionado, required this.onSelect});

  (IconData, Color) _info(String t) {
    switch (t.toLowerCase()) {
      case 'plus':
        return (Icons.workspace_premium_rounded, AppTheme.accent);
      case 'vip':
        return (Icons.star_rounded, const Color(0xFF8B5CF6));
      default:
        return (Icons.directions_car_filled_rounded, AppTheme.primary);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tipos.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _card(tipos[i])),
        ],
      ],
    );
  }

  Widget _card(String tipo) {
    final (icon, color) = _info(tipo);
    final sel = tipo == seleccionado;
    return InkWell(
      onTap: () => onSelect(tipo),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? color : AppTheme.border, width: sel ? 1.6 : 1),
          boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))] : null,
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: color),
                ),
                if (sel)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(tipo,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sel ? color : AppTheme.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Boton deslizable para confirmar la solicitud (evita solicitudes por error).
class _SlideToConfirm extends StatefulWidget {
  final bool enabled;
  final bool loading;
  final String label;
  final VoidCallback onConfirm;
  const _SlideToConfirm({required this.enabled, required this.loading, required this.label, required this.onConfirm});

  @override
  State<_SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<_SlideToConfirm> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    const thumb = 50.0;
    final habilitado = widget.enabled && !widget.loading;
    return LayoutBuilder(builder: (context, c) {
      final maxDrag = (c.maxWidth - thumb - 8).clamp(1.0, double.infinity);
      final progreso = _drag * maxDrag;
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: habilitado ? AppTheme.primary : AppTheme.textMuted,
          borderRadius: BorderRadius.circular(28),
          boxShadow: habilitado
              ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 5))]
              : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 60),
                    width: thumb + 8 + progreso,
                    height: double.infinity,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
            Center(
              child: widget.loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: _drag > 0.05 ? 0.7 : 1),
                      ),
                    ),
            ),
            Positioned(
              left: 4 + progreso,
              top: 4,
              child: GestureDetector(
                onHorizontalDragUpdate: habilitado
                    ? (d) => setState(() => _drag = (_drag + d.delta.dx / maxDrag).clamp(0.0, 1.0))
                    : null,
                onHorizontalDragEnd: (_) {
                  if (_drag > 0.85 && habilitado) {
                    widget.onConfirm();
                  }
                  setState(() => _drag = 0);
                },
                child: Container(
                  width: thumb,
                  height: thumb,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(
                    widget.loading ? Icons.hourglass_top_rounded : Icons.arrow_forward_rounded,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

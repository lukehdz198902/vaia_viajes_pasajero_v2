import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../providers/ride_provider.dart';
import '../widgets/vaia_widgets.dart';
import 'place_search_screen.dart';

class ScheduleRideScreen extends StatefulWidget {
  const ScheduleRideScreen({super.key});

  @override
  State<ScheduleRideScreen> createState() => _ScheduleRideScreenState();
}

class _ScheduleRideScreenState extends State<ScheduleRideScreen> {
  final _originCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  LatLng? _origenLatLng;
  LatLng? _destinoLatLng;
  final List<Map<String, dynamic>> _paradas = [];
  DateTime? _fecha;
  TimeOfDay? _hora;
  bool _loading = false;

  // Mapa de previsualizacion del recorrido
  GoogleMapController? _mapCtrl;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  void _actualizarMapa() {
    final markers = <Marker>{};
    if (_origenLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('origen'),
        position: _origenLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Origen', snippet: _originCtrl.text),
      ));
    }
    if (_destinoLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('destino'),
        position: _destinoLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(title: 'Destino', snippet: _destinoCtrl.text),
      ));
    }
    for (var i = 0; i < _paradas.length; i++) {
      final p = _paradas[i];
      final lat = double.tryParse(p['lat']?.toString() ?? '');
      final lng = double.tryParse(p['lng']?.toString() ?? '');
      if (lat == null || lng == null) continue;
      markers.add(Marker(
        markerId: MarkerId('parada_$i'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: 'Parada ${i + 1}', snippet: p['direccion']?.toString() ?? ''),
      ));
    }
    if (mounted) setState(() => _markers..clear()..addAll(markers));
    _ajustarMapa();
  }

  void _ajustarMapa() {
    if (_mapCtrl == null) return;
    final puntos = <LatLng>[
      if (_origenLatLng != null) _origenLatLng!,
      if (_destinoLatLng != null) _destinoLatLng!,
      ..._paradas.map((p) {
        final lat = double.tryParse(p['lat']?.toString() ?? '');
        final lng = double.tryParse(p['lng']?.toString() ?? '');
        return (lat != null && lng != null) ? LatLng(lat, lng) : null;
      }).whereType<LatLng>(),
    ];
    if (puntos.isEmpty) return;
    if (puntos.length == 1) {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(puntos.first, 15));
      return;
    }
    final lats = puntos.map((p) => p.latitude).toList()..sort();
    final lngs = puntos.map((p) => p.longitude).toList()..sort();
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(lats.first, lngs.first),
        northeast: LatLng(lats.last, lngs.last),
      ),
      70,
    ));
  }

  @override
  void initState() {
    super.initState();
    _cargarUbicacionActual();
  }

  Future<void> _cargarUbicacionActual() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() {
        _origenLatLng = LatLng(pos.latitude, pos.longitude);
        _originCtrl.text = 'Mi ubicacion actual';
      });
      _actualizarMapa();
    } catch (_) {}
  }

  Future<void> _seleccionarLugar({required bool isOrigen}) async {
    final res = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => PlaceSearchScreen(isOrigin: isOrigen)),
    );
    if (res == null) return;
    final latLng = LatLng(res['lat'] as double, res['lng'] as double);
    setState(() {
      if (isOrigen) {
        _origenLatLng = latLng;
        _originCtrl.text = res['address']?.toString() ?? '';
      } else {
        _destinoLatLng = latLng;
        _destinoCtrl.text = res['address']?.toString() ?? '';
      }
    });
    _actualizarMapa();
  }

  Future<void> _agregarParada() async {
    final res = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen(isOrigin: false)),
    );
    if (res == null) return;
    setState(() {
      _paradas.add({
        'direccion': res['address'] ?? 'Parada ${_paradas.length + 1}',
        'lat': (res['lat'] as double).toString(),
        'lng': (res['lng'] as double).toString(),
        'referencia': 'Parada ${_paradas.length + 1}',
      });
    });
    _actualizarMapa();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy.add(const Duration(days: 1)),
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: VaiaColors.primary),
        ),
        child: child!,
      ),
    );
    if (fecha == null) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: VaiaColors.primary),
        ),
        child: child!,
      ),
    );
    if (hora == null) return;
    setState(() {
      _fecha = fecha;
      _hora = hora;
    });
  }

  Future<void> _programar() async {
    if (_origenLatLng == null) { _toast('Selecciona el origen'); return; }
    if (_destinoLatLng == null) { _toast('Selecciona el destino'); return; }
    if (_fecha == null || _hora == null) { _toast('Selecciona fecha y hora'); return; }

    final fechaProgramada = DateTime(_fecha!.year, _fecha!.month, _fecha!.day, _hora!.hour, _hora!.minute);
    if (fechaProgramada.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      _toast('La fecha debe ser al menos 30 minutos en el futuro');
      return;
    }

    setState(() => _loading = true);
    final id = await context.read<RideProvider>().programarServicio(
      dirOrigen: _originCtrl.text,
      latOrigen: _origenLatLng!.latitude.toString(),
      lngOrigen: _origenLatLng!.longitude.toString(),
      dirDestino: _destinoCtrl.text,
      latDestino: _destinoLatLng!.latitude.toString(),
      lngDestino: _destinoLatLng!.longitude.toString(),
      fechaProgramada: fechaProgramada,
      paradas: _paradas,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Viaje programado exitosamente'), backgroundColor: VaiaColors.success,
      ));
      Navigator.of(context).pop(true);
    } else {
      _toast(context.read<RideProvider>().error ?? 'No se pudo programar');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: VaiaColors.danger));
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destinoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Programar viaje'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: VaiaColors.primaryGhost, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: VaiaColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Programa tu viaje con anticipacion. Se asignara un conductor automaticamente antes de la hora.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 210,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VaiaColors.border),
              ),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _origenLatLng ?? const LatLng(26.0923, -98.2789),
                      zoom: 13,
                    ),
                    onMapCreated: (c) { _mapCtrl = c; _ajustarMapa(); },
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                  if (_destinoLatLng == null)
                    Positioned(
                      left: 10, right: 10, bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: VaiaShadows.card,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.map_outlined, size: 16, color: VaiaColors.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('Selecciona el destino para ver el recorrido en el mapa',
                                  style: TextStyle(fontSize: 11.5, color: VaiaColors.textSecondary)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('El mapa muestra el origen, el destino y las paradas que agregues.',
                style: TextStyle(fontSize: 11.5, color: VaiaColors.textMuted)),
            const SizedBox(height: 20),
            VaiaTextField(
              controller: _originCtrl,
              label: 'Origen',
              prefixIcon: Icons.my_location_rounded,
              enabled: false,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _seleccionarLugar(isOrigen: true),
                icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                label: const Text('Cambiar origen'),
              ),
            ),
            VaiaTextField(
              controller: _destinoCtrl,
              label: 'Destino',
              prefixIcon: Icons.location_on_rounded,
              enabled: false,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _seleccionarLugar(isOrigen: false),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Seleccionar destino'),
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _agregarParada,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: Text(_paradas.isEmpty ? 'Agregar parada intermedia' : 'Agregar otra parada'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
            ),
            if (_paradas.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._paradas.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 11, backgroundColor: Colors.orange.shade700,
                        child: Text('${e.key + 1}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.value['direccion']?.toString() ?? '', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(icon: const Icon(Icons.close, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _paradas.removeAt(e.key))),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 16),
            InkWell(
              onTap: _elegirFecha,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VaiaColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _fecha == null ? VaiaColors.border : VaiaColors.primary, width: _fecha == null ? 1 : 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: VaiaColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fecha y hora del viaje', style: TextStyle(fontSize: 12, color: VaiaColors.textMuted, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            _fecha == null || _hora == null
                                ? 'Seleccionar'
                                : DateFormat("EEEE d 'de' MMMM, hh:mm a", 'es').format(
                                    DateTime(_fecha!.year, _fecha!.month, _fecha!.day, _hora!.hour, _hora!.minute)),
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: _fecha == null ? VaiaColors.textMuted : VaiaColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: VaiaColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            VaiaPrimaryButton(
              label: 'Programar viaje',
              icon: Icons.check_rounded,
              loading: _loading,
              onPressed: _loading ? null : _programar,
            ),
          ],
        ),
      ),
    );
  }
}
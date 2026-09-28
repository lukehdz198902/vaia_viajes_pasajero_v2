import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/parada_model.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';
import '../../services/api_service.dart';
import '../../services/directions_service.dart';
import 'report_incident_screen.dart';
import 'service_request_screen.dart';

/// Detalle completo de un servicio para el pasajero: mapa con la ruta y las
/// paradas, datos del conductor, desglose de costos, conversacion y la
/// calificacion que el propio pasajero otorgo (la del conductor es confidencial).
class TripDetailScreen extends StatefulWidget {
  final int idServicio;
  const TripDetailScreen({super.key, required this.idServicio});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  RideModel? _ride;
  List<ParadaModel> _paradas = [];
  List<Map<String, dynamic>> _mensajes = [];
  bool _isLoading = true;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final rideProv = context.read<RideProvider>();
    final api = context.read<ApiService>();

    final ride = await rideProv.detalleViaje(widget.idServicio);
    List<ParadaModel> paradas = [];
    List<Map<String, dynamic>> mensajes = [];
    try {
      final rp = await api.listarParadas(widget.idServicio);
      if (rp.success && rp.list != null) {
        paradas = rp.list!.map((e) => ParadaModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    try {
      final rm = await api.getRoot('Servicio', 'ListarMensajes', params: {'idServicio': widget.idServicio.toString()});
      if (rm.success && rm.list != null) {
        mensajes = rm.list!.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _ride = ride;
      _paradas = paradas;
      _mensajes = mensajes;
      _isLoading = false;
    });
    _construirMapa(ride, paradas);
  }

  Future<void> _construirMapa(RideModel? ride, List<ParadaModel> paradas) async {
    if (ride == null) return;
    final latO = double.tryParse(ride.latOrigen);
    final lngO = double.tryParse(ride.lngOrigen);
    final latD = double.tryParse(ride.latDestino);
    final lngD = double.tryParse(ride.lngDestino);
    if (latO == null || lngO == null) return;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(latO, lngO),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Origen', snippet: ride.direccionOrigen),
      ),
    };
    if (latD != null && lngD != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(latD, lngD),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(title: 'Destino', snippet: ride.direccionDestino),
      ));
    }
    for (var i = 0; i < paradas.length; i++) {
      final p = paradas[i];
      final lat = double.tryParse(p.lat);
      final lng = double.tryParse(p.lng);
      if (lat == null || lng == null) continue;
      markers.add(Marker(
        markerId: MarkerId('parada_${p.id}'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: 'Parada ${p.orden}', snippet: p.direccion),
      ));
    }
    if (mounted) setState(() => _markers..clear()..addAll(markers));

    if (latD == null || lngD == null) return;
    final puntosParadas = paradas
        .map((p) => (double.tryParse(p.lat), double.tryParse(p.lng)))
        .where((e) => e.$1 != null && e.$2 != null)
        .map((e) => LatLng(e.$1!, e.$2!))
        .toList();
    final ruta = await DirectionsService.ruta(
      origen: LatLng(latO, lngO),
      destino: LatLng(latD, lngD),
      paradas: puntosParadas,
    );
    if (!mounted) return;
    if (ruta != null && ruta.puntos.isNotEmpty) {
      setState(() {
        _polylines
          ..clear()
          ..add(Polyline(
            polylineId: const PolylineId('ruta'),
            points: ruta.puntos,
            color: VaiaColors.primary,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ));
      });
    }
  }

  Color _statusColor(String? estatus) {
    final e = (estatus ?? '').toLowerCase();
    if (e.contains('finaliz') || e.contains('pagad')) return VaiaColors.success;
    if (e.contains('cancel')) return VaiaColors.danger;
    if (e.contains('camino')) return VaiaColors.primary;
    return VaiaColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaiaColors.bgLight,
      appBar: AppBar(title: Text(_ride != null ? 'Viaje #${_ride!.id}' : 'Detalle del viaje')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ride == null
              ? const Center(child: Text('No se pudo cargar el detalle'))
              : RefreshIndicator(
                  color: VaiaColors.primary,
                  onRefresh: _loadDetail,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _mapa(),
                      const SizedBox(height: 12),
                      _encabezado(),
                      const SizedBox(height: 12),
                      _ruta(),
                      const SizedBox(height: 12),
                      if (_ride!.conductor != null) ...[_conductor(), const SizedBox(height: 12)],
                      _finanzas(),
                      const SizedBox(height: 12),
                      if (_ride!.calificacion != null && _ride!.calificacion! > 0) ...[_miCalificacion(), const SizedBox(height: 12)],
                      _infoRuta(),
                      const SizedBox(height: 12),
                      if (_paradas.isNotEmpty) ...[_paradasCard(), const SizedBox(height: 12)],
                      _conversacion(),
                      const SizedBox(height: 16),
                      _acciones(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VaiaColors.surface,
          borderRadius: BorderRadius.circular(VaiaRadius.lg),
          border: Border.all(color: VaiaColors.border),
          boxShadow: VaiaShadows.card,
        ),
        child: child,
      );

  Widget _titulo(IconData icon, String texto, {Color color = VaiaColors.primary}) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
        ],
      );

  Widget _mapa() {
    final latO = double.tryParse(_ride!.latOrigen);
    final lngO = double.tryParse(_ride!.lngOrigen);
    if (latO == null || lngO == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(VaiaRadius.lg),
      child: SizedBox(
        height: 200,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(latO, lngO), zoom: 13),
          markers: _markers,
          polylines: _polylines,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
        ),
      ),
    );
  }

  Widget _encabezado() {
    final color = _statusColor(_ride!.estatus);
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Servicio #${_ride!.id}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
                const SizedBox(height: 3),
                Text(_formatDate(_ride!.fechaCreacion), style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(_ride!.estatus ?? '--', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _ruta() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.route_rounded, 'Recorrido'),
            const SizedBox(height: 12),
            _dirRow(Icons.trip_origin, VaiaColors.success, 'Origen', _ride!.direccionOrigen),
            Padding(padding: const EdgeInsets.only(left: 5), child: Container(width: 2, height: 16, color: VaiaColors.border)),
            _dirRow(Icons.location_on_rounded, VaiaColors.danger, 'Destino', _ride!.direccionDestino),
          ],
        ),
      );

  Widget _dirRow(IconData icon, Color color, String label, String valor) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: VaiaColors.textMuted, letterSpacing: 0.4)),
                Text(valor.isEmpty ? '-' : valor, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary)),
              ],
            ),
          ),
        ],
      );

  Widget _conductor() {
    final c = _ride!.conductor!;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo(Icons.person_rounded, 'Tu conductor'),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: VaiaColors.primaryGhost,
                backgroundImage: (c.fotoperfil != null && c.fotoperfil!.isNotEmpty) ? NetworkImage(c.fotoperfil!) : null,
                child: (c.fotoperfil == null || c.fotoperfil!.isEmpty) ? const Icon(Icons.person_rounded, color: VaiaColors.primary, size: 28) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nombreCompleto, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                    if (c.calificacion != null && c.calificacion! > 0)
                      Row(children: [
                        const Icon(Icons.star_rounded, size: 15, color: VaiaColors.accent),
                        const SizedBox(width: 3),
                        Text(c.calificacion!.toStringAsFixed(1), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        if ((c.totalViajes ?? 0) > 0)
                          Text('  -  ${c.totalViajes} viajes', style: const TextStyle(fontSize: 12, color: VaiaColors.textSecondary)),
                      ]),
                  ],
                ),
              ),
            ],
          ),
          if ((c.unidad ?? '').isNotEmpty || (c.placas ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: VaiaColors.bgSubtle, borderRadius: BorderRadius.circular(VaiaRadius.md)),
              child: Row(children: [
                const Icon(Icons.directions_car_rounded, size: 16, color: VaiaColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text([c.marca, c.submarca, c.modelo].whereType<String>().where((e) => e.trim().isNotEmpty).join(' '),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary))),
                if ((c.placas ?? '').isNotEmpty)
                  Text(c.placas!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary, letterSpacing: 1)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _finanzas() {
    final total = _ride!.montoActual;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo(Icons.receipt_long_rounded, 'Resumen financiero'),
          const SizedBox(height: 12),
          _fila('Costo estimado', '\$${_ride!.costoEstimado.toStringAsFixed(2)}'),
          if ((_ride!.costoEnCurso ?? 0) > 0) _fila('Costo en curso', '\$${_ride!.costoEnCurso!.toStringAsFixed(2)}'),
          if (_ride!.montoDescuento != null && _ride!.montoDescuento! > 0)
            _fila('Descuento', '-\$${_ride!.montoDescuento!.toStringAsFixed(2)}', color: VaiaColors.success),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
              Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: VaiaColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          _fila('Tipo de viaje', _ride!.tipoviaje ?? '--'),
          _fila('Forma de pago', _ride!.metodoPago ?? _ride!.tipoPago ?? '--'),
        ],
      ),
    );
  }

  Widget _miCalificacion() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.star_rounded, 'Tu calificacion', color: VaiaColors.accent),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) => Icon(
                    i < _ride!.calificacion! ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 26,
                    color: i < _ride!.calificacion! ? VaiaColors.accent : VaiaColors.borderStrong,
                  )),
            ),
          ],
        ),
      );

  Widget _infoRuta() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.info_outline_rounded, 'Informacion del viaje'),
            const SizedBox(height: 12),
            _infoRow(Icons.straighten_rounded, 'Distancia', _ride!.distanciaFormateada),
            const SizedBox(height: 8),
            _infoRow(Icons.access_time_rounded, 'Duracion', _formatDuration(_ride!.duracionSegundos)),
            const SizedBox(height: 8),
            _infoRow(Icons.event_available_rounded, 'Iniciado', _formatDate(_ride!.fechaServicioIniciado)),
            const SizedBox(height: 8),
            _infoRow(Icons.flag_rounded, 'Finalizado', _formatDate(_ride!.fechaLlegoDestino)),
          ],
        ),
      );

  Widget _paradasCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo(Icons.alt_route_rounded, 'Paradas (${_paradas.where((p) => p.completada).length}/${_paradas.length})', color: VaiaColors.accent),
            const SizedBox(height: 10),
            ..._paradas.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(p.completada ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          size: 17, color: p.completada ? VaiaColors.success : VaiaColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${p.orden}. ${p.direccion}',
                            style: TextStyle(
                              fontSize: 12.5,
                              decoration: p.completada ? TextDecoration.lineThrough : null,
                              color: p.completada ? VaiaColors.textMuted : VaiaColors.textPrimary,
                            )),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );

  Widget _conversacion() {
    if (_mensajes.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titulo(Icons.chat_bubble_rounded, 'Conversacion (${_mensajes.length})'),
          const SizedBox(height: 12),
          ..._mensajes.map((m) {
            final esMio = m['desdeapppasajero'] == true || m['desdeapppasajero']?.toString() == '1' || m['desdeapppasajero']?.toString() == 'true';
            return Align(
              alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                decoration: BoxDecoration(
                  color: esMio ? VaiaColors.primary : VaiaColors.bgSubtle,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['mensaje']?.toString() ?? '',
                        style: TextStyle(fontSize: 13, color: esMio ? Colors.white : VaiaColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(_hora(m['fechacreacion']),
                        style: TextStyle(fontSize: 9.5, color: esMio ? Colors.white70 : VaiaColors.textMuted)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _acciones() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ServiceRequestScreen(
                  currentLat: double.tryParse(_ride!.latOrigen) ?? 0,
                  currentLng: double.tryParse(_ride!.lngOrigen) ?? 0,
                ),
              ));
            },
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Re-solicitar'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportIncidentScreen(idServicio: _ride!.id))),
            style: OutlinedButton.styleFrom(foregroundColor: VaiaColors.danger, side: const BorderSide(color: VaiaColors.danger)),
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Reportar incidente'),
          ),
        ),
      ],
    );
  }

  Widget _fila(String label, String valor, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13.5, color: VaiaColors.textSecondary)),
            Text(valor, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color ?? VaiaColors.textPrimary)),
          ],
        ),
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: VaiaColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13.5, color: VaiaColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary)),
        ],
      );

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--';
    }
  }

  String _hora(dynamic iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '--';
    final min = (seconds / 60).round();
    if (min < 60) return '$min min';
    return '${(min / 60).floor()}h ${min % 60}min';
  }
}

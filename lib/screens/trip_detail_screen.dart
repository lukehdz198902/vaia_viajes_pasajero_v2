import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';
import 'report_incident_screen.dart';
import 'service_request_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final int idServicio;

  const TripDetailScreen({super.key, required this.idServicio});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  RideModel? _ride;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final ride = await context.read<RideProvider>().detalleViaje(widget.idServicio);
    if (!mounted) return;
    setState(() {
      _ride = ride;
      _isLoading = false;
    });
  }

  Color _statusColor(String? estatus) {
    switch (estatus?.toLowerCase()) {
      case 'finalizado':
        return Colors.green;
      case 'cancelado':
        return AppTheme.danger;
      case 'en camino':
        return AppTheme.primary;
      default:
        return AppTheme.textMedium;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '--';
    final min = (seconds / 60).round();
    if (min < 60) return '$min min';
    return '${(min / 60).floor()}h ${min % 60}min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Detalle del Viaje'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        titleTextStyle: const TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ride == null
          ? const Center(child: Text('No se pudo cargar el detalle'))
          : RefreshIndicator(
              onRefresh: _loadDetail,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildRouteCard(),
                    const SizedBox(height: 12),
                    if (_ride!.conductor != null) ...[_buildConductorCard(), const SizedBox(height: 12)],
                    _buildFinancialCard(),
                    if (_ride!.calificacionPasajero != null && _ride!.calificacionPasajero! > 0) ...[
                      const SizedBox(height: 12),
                      _buildRatingCard(),
                    ],
                    const SizedBox(height: 12),
                    _buildRouteInfoCard(),
                    const SizedBox(height: 20),
                    _buildActions(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final color = _statusColor(_ride!.estatus);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servicio #${_ride!.id}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(_ride!.fechaCreacion),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMedium),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(
                _ride!.estatus ?? '--',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard() {
    final latO = double.tryParse(_ride!.latOrigen);
    final lngO = double.tryParse(_ride!.lngOrigen);
    final latD = double.tryParse(_ride!.latDestino);
    final lngD = double.tryParse(_ride!.lngDestino);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.route, size: 18, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Ruta del viaje',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (latO != null && lngO != null && latD != null && lngD != null)
              SizedBox(
                height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng((latO + latD) / 2, (lngO + lngD) / 2),
                      zoom: 13,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('origin'),
                        position: LatLng(latO, lngO),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                        infoWindow: const InfoWindow(title: 'Origen'),
                      ),
                      Marker(
                        markerId: const MarkerId('destination'),
                        position: LatLng(latD, lngD),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
                        infoWindow: const InfoWindow(title: 'Destino'),
                      ),
                    },
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _buildAddressRow(Icons.circle, AppTheme.primary, _ride!.direccionOrigen),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: SizedBox(
                height: 16,
                child: Row(
                  children: [Text('  |', style: TextStyle(color: AppTheme.border))],
                ),
              ),
            ),
            _buildAddressRow(Icons.location_on, AppTheme.danger, _ride!.direccionDestino),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, Color color, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(address, style: const TextStyle(fontSize: 14, color: AppTheme.textDark)),
        ),
      ],
    );
  }

  Widget _buildConductorCard() {
    final cond = _ride!.conductor!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Conductor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.bgLight,
                  backgroundImage: cond.fotoperfil != null ? NetworkImage(cond.fotoperfil!) : null,
                  child: cond.fotoperfil == null ? const Icon(Icons.person, size: 28, color: AppTheme.textLight) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cond.nombreCompleto,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      ),
                      if (cond.calificacion != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: AppTheme.secondary),
                            const SizedBox(width: 4),
                            Text(
                              cond.calificacion!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 14, color: AppTheme.textMedium),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (cond.telefono != null)
                  IconButton(
                    icon: const Icon(Icons.phone, color: AppTheme.primary),
                    onPressed: () {
                      // TODO: launch phone dialer
                    },
                  ),
              ],
            ),
            if (cond.unidad != null || cond.placas != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.directions_car, size: 14, color: AppTheme.textMedium),
                  const SizedBox(width: 6),
                  Text(
                    [if (cond.unidad != null) cond.unidad, if (cond.placas != null) cond.placas].join(' - '),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMedium),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long, size: 18, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Resumen financiero',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFinanceRow('Costo', _ride!.costoFormateado),
            if (_ride!.montoDescuento != null && _ride!.montoDescuento! > 0)
              _buildFinanceRow(
                'Descuento',
                '-\$${_ride!.montoDescuento!.toStringAsFixed(2)}',
                valueColor: Colors.green,
              ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Metodo de pago', style: TextStyle(fontSize: 14, color: AppTheme.textMedium)),
                Text(
                  _ride!.tipoviaje ?? 'Efectivo',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textMedium)),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, size: 18, color: AppTheme.secondary),
                SizedBox(width: 8),
                Text(
                  'Tu calificacion',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < _ride!.calificacionPasajero! ? Icons.star : Icons.star_border,
                  size: 24,
                  color: i < _ride!.calificacionPasajero! ? AppTheme.secondary : AppTheme.border,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Informacion de ruta',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.straighten, 'Distancia', _ride!.distanciaFormateada),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, 'Duracion', _formatDuration(_ride!.duracionSegundos)),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.route_outlined, 'Tipo de viaje', _ride!.tipoviaje ?? 'URBANO'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMedium),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textMedium)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServiceRequestScreen(
                    currentLat: double.tryParse(_ride!.latOrigen) ?? 0,
                    currentLng: double.tryParse(_ride!.lngOrigen) ?? 0,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.replay),
            label: const Text('Re-solicitar'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => ReportIncidentScreen(idServicio: _ride!.id)));
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.danger),
            ),
            icon: const Icon(Icons.warning_amber_outlined),
            label: const Text('Reportar incidente'),
          ),
        ),
      ],
    );
  }
}

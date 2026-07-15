import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/ride_provider.dart';
import '../../config/theme.dart';
import '../../models/ride_model.dart';
import 'rating_screen.dart';
import 'chat_screen.dart';

class ServiceStatusScreen extends StatefulWidget {
  const ServiceStatusScreen({super.key});

  @override
  State<ServiceStatusScreen> createState() => _ServiceStatusScreenState();
}

class _ServiceStatusScreenState extends State<ServiceStatusScreen> {
  Timer? _pollTimer;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _startPolling();
    _updateMap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final ride = context.read<RideProvider>();
      final estatus = ride.currentRide?.estatus?.toLowerCase() ?? '';
      if (estatus == 'finalizado') {
        _pollTimer?.cancel();
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RatingScreen()));
      }
    });
  }

  void _updateMap() {
    final ride = context.read<RideProvider>().currentRide;
    if (ride == null) return;

    _markers.clear();

    if (ride.latOrigen.isNotEmpty && ride.lngOrigen.isNotEmpty) {
      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(double.parse(ride.latOrigen), double.parse(ride.lngOrigen)),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Origen'),
        ),
      );
    }

    if (ride.latDestino.isNotEmpty && ride.lngDestino.isNotEmpty) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(double.parse(ride.latDestino), double.parse(ride.lngDestino)),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          infoWindow: const InfoWindow(title: 'Destino'),
        ),
      );
    }

    if (ride.conductor?.lat != null &&
        ride.conductor?.lng != null &&
        ride.conductor!.lat!.isNotEmpty &&
        ride.conductor!.lng!.isNotEmpty) {
      _markers.add(
        Marker(
          markerId: const MarkerId('vehicle'),
          position: LatLng(double.parse(ride.conductor!.lat!), double.parse(ride.conductor!.lng!)),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Vehiculo'),
        ),
      );
    }

    setState(() {});
  }

  Color _statusColor(String? estatus) {
    switch (estatus?.toLowerCase()) {
      case 'solicitado':
        return AppTheme.secondary;
      case 'en camino':
        return AppTheme.primary;
      case 'en viaje':
        return AppTheme.accent;
      case 'finalizado':
        return Colors.green;
      default:
        return AppTheme.textMedium;
    }
  }

  String _statusLabel(String? estatus) {
    switch (estatus?.toLowerCase()) {
      case 'solicitado':
        return 'Solicitado';
      case 'en camino':
        return 'En Camino';
      case 'en viaje':
        return 'En Viaje';
      case 'finalizado':
        return 'Finalizado';
      default:
        return estatus ?? '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>().currentRide;

    if (ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tu Viaje')),
        body: const Center(child: Text('No hay un viaje activo')),
      );
    }

    final cond = ride.conductor;
    final estatus = ride.estatus ?? '';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<RideProvider>().stopPolling();
          _pollTimer?.cancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tu Viaje'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.read<RideProvider>().stopPolling();
              _pollTimer?.cancel();
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(flex: 3, child: _buildMapSection(ride)),
            Expanded(flex: 2, child: _buildBottomPanel(ride, cond, estatus)),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(RideModel ride) {
    final latOrigen = double.tryParse(ride.latOrigen) ?? 0;
    final lngOrigen = double.tryParse(ride.lngOrigen) ?? 0;

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: LatLng(latOrigen, lngOrigen), zoom: 14),
      onMapCreated: (ctrl) {},
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
    );
  }

  Widget _buildBottomPanel(RideModel ride, dynamic cond, String estatus) {
    final isCancelable = estatus.toLowerCase() == 'solicitado' || estatus.toLowerCase() == 'en camino';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.bgLight,
                    child: cond?.fotoperfil != null
                        ? ClipOval(
                            child: Image.network(
                              cond!.fotoperfil!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(Icons.person, color: AppTheme.textLight, size: 28),
                            ),
                          )
                        : Icon(Icons.person, color: AppTheme.textLight, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cond?.nombreCompleto ?? 'Conductor asignado...',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        ),
                        if (cond != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${cond.unidad ?? ''} ${cond.placas ?? ''}'.trim(),
                            style: TextStyle(fontSize: 13, color: AppTheme.textMedium),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (cond?.calificacion != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: AppTheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                            cond!.calificacion!.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: AppTheme.textMedium),
                  const SizedBox(width: 4),
                  Text(
                    ride.duracionSegundos != null
                        ? '${(ride.duracionSegundos! / 60).ceil()} min restantes'
                        : 'Calculando tiempo...',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMedium),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.route_outlined, size: 16, color: AppTheme.textMedium),
                  const SizedBox(width: 4),
                  Text(ride.distanciaFormateada, style: TextStyle(fontSize: 13, color: AppTheme.textMedium)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(estatus).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(estatus),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor(estatus)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (cond != null) ...[
                    Expanded(
                      child: _actionButton(
                        icon: Icons.chat_bubble_outline,
                        label: 'Chat',
                        color: AppTheme.primary,
                        onTap: () {
                          final ride = context.read<RideProvider>().currentRide;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                idServicio: ride?.id ?? 0,
                                conductorNombre: ride?.conductorNombre ?? 'Conductor',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        icon: Icons.phone_outlined,
                        label: 'Llamar',
                        color: AppTheme.accent,
                        onTap: () {
                          // Launch phone dial
                        },
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.warning_amber_rounded,
                      label: 'SOS',
                      color: AppTheme.danger,
                      onTap: () async {
                        final rideProv = context.read<RideProvider>();
                        if (rideProv.currentRide != null) {
                          await rideProv.activarAlarmaSOS(rideProv.currentRide!.id);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Alarma SOS enviada'), backgroundColor: Colors.red),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (isCancelable) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancelar Servicio'),
                          content: const Text('Estas seguro de cancelar este servicio?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text('Si, cancelar', style: TextStyle(color: AppTheme.danger)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        await context.read<RideProvider>().cancelarServicio();
                        if (mounted) Navigator.of(context).pop();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                    ),
                    child: const Text('Cancelar Servicio'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

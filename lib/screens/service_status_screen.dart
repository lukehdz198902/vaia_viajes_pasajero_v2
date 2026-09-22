import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/ride_provider.dart';
import '../../config/theme.dart';
import '../../models/ride_model.dart';
import '../../services/api_service.dart';
import 'rating_screen.dart';
import 'chat_screen.dart';
import 'report_incident_screen.dart';

class ServiceStatusScreen extends StatefulWidget {
  const ServiceStatusScreen({super.key});

  @override
  State<ServiceStatusScreen> createState() => _ServiceStatusScreenState();
}

class _ServiceStatusScreenState extends State<ServiceStatusScreen> {
  final Set<Marker> _markers = {};
  BitmapDescriptor? _carIcon;
  LatLng? _ultimaPosVehiculo;
  double _bearingVehiculo = 0;

  @override
  void initState() {
    super.initState();
    _cargarIconoCarrito();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFinished();
      _updateMap();
      final ride = context.read<RideProvider>().currentRide;
      if (ride != null) context.read<RideProvider>().listarParadas(ride.id);
    });
  }

  Future<void> _cargarIconoCarrito() async {
    try {
      final data = await rootBundle.load('assets/images/car.png');
      final bd = BitmapDescriptor.fromBytes(data.buffer.asUint8List());
      if (mounted) setState(() => _carIcon = bd);
    } catch (_) {}
  }

  /// Rumbo en grados desde `a` hacia `b` (0 = norte).
  double _calcularBearing(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180.0 / math.pi;
    return (brng + 360.0) % 360.0;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMap();
  }

  void _checkFinished() {
    final ride = context.read<RideProvider>().currentRide;
    if (ride != null && (ride.estatus?.toLowerCase() == 'finalizado')) {
      context.read<RideProvider>().stopPolling();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RatingScreen()));
    }
  }

  /// Pago en linea con MercadoPago o PayPal: abre el link de pago en el navegador.
  Future<void> _pagarEnLinea(int idServicio) async {
    final metodo = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pagar en linea'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'mercadopago'),
            child: const Row(children: [Icon(Icons.account_balance_wallet_outlined), SizedBox(width: 12), Text('MercadoPago')]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'paypal'),
            child: const Row(children: [Icon(Icons.payments_outlined), SizedBox(width: 12), Text('PayPal')]),
          ),
        ],
      ),
    );
    if (metodo == null) return;

    final api = context.read<ApiService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? url;
      if (metodo == 'mercadopago') {
        final res = await api.mercadoPagoPreferencia(idServicio);
        url = (res.data?['initPoint'] ?? res.data?['sandboxInitPoint'])?.toString();
      } else {
        final res = await api.paypalCrearOrden(idServicio);
        url = res.data?['approveUrl']?.toString();
      }
      if (url == null || url.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo iniciar el pago'), backgroundColor: AppTheme.danger));
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir la pasarela de pago'), backgroundColor: AppTheme.danger));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al pagar: $e'), backgroundColor: AppTheme.danger));
    }
  }

  void _updateMap() {
    final rideProv = context.read<RideProvider>();
    final ride = rideProv.currentRide;
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

    // Ubicacion en vivo del conductor (SignalR) con respaldo en el snapshot
    final vLat = rideProv.conductorLat ?? double.tryParse(ride.conductor?.lat ?? '');
    final vLng = rideProv.conductorLng ?? double.tryParse(ride.conductor?.lng ?? '');
    if (vLat != null && vLng != null) {
      final posVeh = LatLng(vLat, vLng);
      if (_ultimaPosVehiculo != null &&
          (_ultimaPosVehiculo!.latitude != vLat || _ultimaPosVehiculo!.longitude != vLng)) {
        _bearingVehiculo = _calcularBearing(_ultimaPosVehiculo!, posVeh);
      }
      _ultimaPosVehiculo = posVeh;
      _markers.add(
        Marker(
          markerId: const MarkerId('vehicle'),
          position: posVeh,
          rotation: _bearingVehiculo,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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

  Future<void> _callConductor(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede realizar la llamada'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _finalizarViaje() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Viaje'),
        content: const Text('Confirmas que has llegado a tu destino?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Si, finalizar', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final ride = context.read<RideProvider>();
      if (ride.currentRide != null) {
        ride.stopPolling();
        ride.clearCurrentRide();
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RatingScreen()));
      }
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

    if (ride.estatus?.toLowerCase() == 'finalizado') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<RideProvider>().stopPolling();
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RatingScreen()));
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Tu Viaje')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final cond = ride.conductor;
    final estatus = ride.estatus ?? '';
    final isEnCamino = estatus.toLowerCase() == 'en camino';
    final isEnViaje = estatus.toLowerCase() == 'en viaje';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) context.read<RideProvider>().stopPolling();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tu Viaje'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.read<RideProvider>().stopPolling();
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(flex: 3, child: _buildMapSection(ride)),
            Expanded(flex: 2, child: _buildBottomPanel(ride, cond, estatus, isEnCamino, isEnViaje)),
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

  Widget _buildBottomPanel(RideModel ride, dynamic cond, String estatus, bool isEnCamino, bool isEnViaje) {
    final isCancelable = estatus.toLowerCase() == 'solicitado' || isEnCamino;

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
          child: SingleChildScrollView(
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
                            if ((cond.totalViajes ?? 0) > 0)
                              Text('${cond.totalViajes} viajes completados',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textLight)),
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
                if (context.watch<RideProvider>().paradas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildParadasPanel(),
                ],
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
                                  conductorFoto: cond?.fotoperfil,
                                  conductorTelefono: cond?.telefono,
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
                          onTap: () => _callConductor(cond?.telefono),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onLongPress: () async {
                          final rideProv = context.read<RideProvider>();
                          if (rideProv.currentRide != null) {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Enviar SOS'),
                                content: const Text('Se enviara una alerta de emergencia. Deseas continuar?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: Text('Enviar SOS', style: TextStyle(color: AppTheme.danger)),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && mounted) {
                              await rideProv.activarAlarmaSOS(rideProv.currentRide!.id);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Alarma SOS enviada'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 22),
                              const SizedBox(height: 4),
                              Text(
                                'SOS',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.danger),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Codigo de inicio que el pasajero comparte con el conductor
                if (ride.codigoInicio != null && ride.codigoInicio!.isNotEmpty && !isEnViaje) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.vpn_key_outlined, size: 18, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Text('Codigo de inicio',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ride.codigoInicio!,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 8),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Comparte este codigo con tu conductor para iniciar el viaje',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textMedium),
                        ),
                      ],
                    ),
                  ),
                ],
                // Taximetro: cobro en vivo durante el viaje
                if (isEnViaje || (ride.costoFinal ?? 0) > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      children: [
                        const Text('Total del viaje',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                        const SizedBox(height: 6),
                        Text(
                          '\$${((ride.costoFinal ?? 0) > 0 ? ride.costoFinal! : (ride.costoEnCurso ?? ride.costoEstimado)).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEnViaje ? 'El cobro se actualiza en tiempo real' : 'Costo final',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _pagarEnLinea(ride.id),
                      icon: const Icon(Icons.credit_card),
                      label: const Text('Pagar en linea (MercadoPago / PayPal)'),
                    ),
                  ),
                ],
                if (isEnViaje) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _finalizarViaje,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Llegue a mi destino'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportIncidentScreen(idServicio: ride.id),
                            ),
                          );
                        },
                        icon: Icon(Icons.report_problem_outlined, size: 18, color: AppTheme.textMedium),
                        label: Text(
                          'Incidente',
                          style: TextStyle(color: AppTheme.textMedium, fontSize: 13),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            '/support-chat',
                            arguments: {'idServicio': ride.id},
                          );
                        },
                        icon: const Icon(Icons.support_agent_rounded, size: 18, color: AppTheme.primary),
                        label: const Text(
                          'Soporte',
                          style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParadasPanel() {
    final paradas = context.watch<RideProvider>().paradas;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, size: 16, color: Colors.orange.shade800),
              const SizedBox(width: 6),
              Text(
                'Paradas intermedias (${paradas.where((p) => p.completada).length}/${paradas.length})',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange.shade900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...paradas.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      p.completada ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: p.completada ? AppTheme.accent : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${p.orden}. ${p.direccion}',
                        style: TextStyle(
                          fontSize: 12,
                          decoration: p.completada ? TextDecoration.lineThrough : null,
                          color: p.completada ? AppTheme.textLight : AppTheme.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
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

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback, rootBundle;
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/ride_provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/ride_model.dart';
import '../../services/api_service.dart';
import '../../services/directions_service.dart';
import '../../widgets/status_timeline.dart';
import 'rating_screen.dart';
import 'chat_screen.dart';
import 'report_incident_screen.dart';

/// Pantalla principal del servicio en curso del pasajero.
///
/// Mapa a pantalla completa + panel deslizable con linea de tiempo animada,
/// datos completos del conductor, codigo de inicio, tarifa en vivo, paradas y
/// acciones. Se alimenta por WebSocket (snapshot completo en cada estatus).
class ServiceStatusScreen extends StatefulWidget {
  const ServiceStatusScreen({super.key});

  @override
  State<ServiceStatusScreen> createState() => _ServiceStatusScreenState();
}

class _ServiceStatusScreenState extends State<ServiceStatusScreen> {
  GoogleMapController? _mapCtrl;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  BitmapDescriptor? _carIcon;
  LatLng? _ultimaPosVehiculo;
  double _bearingVehiculo = 0;
  bool _trazando = false;
  String _claveTrazo = '';
  bool _yaNavegoFin = false;
  bool _copiado = false;
  int _ultimoPasoCamara = -99;
  RideProvider? _rideRef;

  @override
  void initState() {
    super.initState();
    _cargarIconoCarrito();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rideRef = context.read<RideProvider>();
      _rideRef!.addListener(_onRideChanged);
      final r = _rideRef!.currentRide;
      if (r != null) {
        _rideRef!.listarParadas(r.id);
        _rideRef!.refrescarServicio();
      }
      _actualizarMapa(forzar: true);
    });
  }

  void _onRideChanged() {
    if (mounted) _actualizarMapa();
  }

  @override
  void dispose() {
    _rideRef?.removeListener(_onRideChanged);
    super.dispose();
  }

  Future<void> _cargarIconoCarrito() async {
    try {
      final data = await rootBundle.load('assets/images/car.png');
      final bd = BitmapDescriptor.fromBytes(data.buffer.asUint8List());
      if (mounted) setState(() => _carIcon = bd);
    } catch (_) {}
  }

  double _calcularBearing(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
  }

  // ─── Mapa ─────────────────────────────────────────────────────

  void _actualizarMapa({bool forzar = false}) {
    final rideProv = context.read<RideProvider>();
    final ride = rideProv.currentRide;
    if (ride == null) return;

    _markers.clear();

    final oLat = double.tryParse(ride.latOrigen);
    final oLng = double.tryParse(ride.lngOrigen);
    final dLat = double.tryParse(ride.latDestino);
    final dLng = double.tryParse(ride.lngDestino);

    if (oLat != null && oLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(oLat, oLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Origen', snippet: ride.direccionOrigen),
      ));
    }
    if (dLat != null && dLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(dLat, dLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(title: 'Destino', snippet: ride.direccionDestino),
      ));
    }

    final vLat = rideProv.conductorLat ?? double.tryParse(ride.conductor?.lat ?? '');
    final vLng = rideProv.conductorLng ?? double.tryParse(ride.conductor?.lng ?? '');
    LatLng? posVeh;
    if (vLat != null && vLng != null) {
      posVeh = LatLng(vLat, vLng);
      if (_ultimaPosVehiculo != null && (_ultimaPosVehiculo!.latitude != vLat || _ultimaPosVehiculo!.longitude != vLng)) {
        _bearingVehiculo = _calcularBearing(_ultimaPosVehiculo!, posVeh);
      }
      _ultimaPosVehiculo = posVeh;
      _markers.add(Marker(
        markerId: const MarkerId('vehicle'),
        position: posVeh,
        rotation: _bearingVehiculo,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Tu conductor'),
      ));
    }

    // Ruta: al origen mientras el conductor llega; al destino durante el viaje.
    final irADestino = ride.esEnViaje;
    if (_debeRetrazarRuta(ride, irADestino)) {
      _trazarRuta(ride: ride, irADestino: irADestino, posVeh: posVeh, oLat: oLat, oLng: oLng, dLat: dLat, dLng: dLng);
    }

    final cambioPaso = _ultimoPasoCamara != ride.pasoActual;
    _ultimoPasoCamara = ride.pasoActual;
    if (forzar || cambioPaso) _ajustarCamara(ride, posVeh, oLat, oLng, dLat, dLng);
    setState(() {});
  }

  bool _debeRetrazarRuta(RideModel ride, bool irADestino) {
    final origen = irADestino ? '${ride.latOrigen},${ride.lngOrigen}' : '${ride.conductor?.lat ?? ride.latOrigen},${ride.conductor?.lng ?? ride.lngOrigen}';
    final clave = '${ride.id}|$irADestino|$origen';
    if (clave == _claveTrazo) return false;
    _claveTrazo = clave;
    return true;
  }

  Future<void> _trazarRuta({
    required RideModel ride,
    required bool irADestino,
    required LatLng? posVeh,
    required double? oLat,
    required double? oLng,
    required double? dLat,
    required double? dLng,
  }) async {
    if (_trazando) return;
    LatLng? inicio;
    LatLng? fin;
    if (irADestino) {
      if (oLat != null && oLng != null) inicio = LatLng(oLat, oLng);
      if (dLat != null && dLng != null) fin = LatLng(dLat, dLng);
    } else {
      inicio = posVeh ?? (oLat != null && oLng != null ? LatLng(oLat, oLng) : null);
      if (oLat != null && oLng != null) fin = LatLng(oLat, oLng);
    }
    if (inicio == null || fin == null) return;

    _trazando = true;
    final ruta = await DirectionsService.ruta(origen: inicio, destino: fin);
    _trazando = false;
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

  void _ajustarCamara(RideModel ride, LatLng? posVeh, double? oLat, double? oLng, double? dLat, double? dLng) {
    if (_mapCtrl == null) return;
    final puntos = <LatLng>[];
    if (posVeh != null) puntos.add(posVeh);
    if (oLat != null && oLng != null) puntos.add(LatLng(oLat, oLng));
    if (ride.esEnViaje && dLat != null && dLng != null) puntos.add(LatLng(dLat, dLng));
    if (puntos.length < 2) {
      if (puntos.isNotEmpty) _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(puntos.first, 15));
      return;
    }
    var minLat = puntos.first.latitude, maxLat = puntos.first.latitude;
    var minLng = puntos.first.longitude, maxLng = puntos.first.longitude;
    for (final p in puntos) {
      minLat = math.min(minLat, p.latitude); maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude); maxLng = math.max(maxLng, p.longitude);
    }
    final bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ─── Acciones ─────────────────────────────────────────────────

  Future<void> _copiarCodigo(String codigo) async {
    await Clipboard.setData(ClipboardData(text: codigo));
    if (!mounted) return;
    setState(() => _copiado = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Codigo copiado')));
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _copiado = false); });
  }

  Future<void> _llamar(String? telefono) async {
    if (telefono == null || telefono.isEmpty) return;
    final uri = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(uri)) { await launchUrl(uri); }
  }

  Future<void> _pagarEnLinea(int idServicio) async {
    final metodo = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pagar en linea'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
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
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo iniciar el pago'), backgroundColor: VaiaColors.danger));
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo abrir la pasarela de pago'), backgroundColor: VaiaColors.danger));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al pagar: $e'), backgroundColor: VaiaColors.danger));
    }
  }

  Future<void> _sos(RideProvider ride, int idServicio) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: VaiaColors.danger), SizedBox(width: 8), Text('Enviar SOS')]),
        content: const Text('Se enviara una alerta de emergencia a los administradores con tu ubicacion. Deseas continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VaiaColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar SOS'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    HapticFeedback.heavyImpact();
    await ride.activarAlarmaSOS(idServicio);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alarma SOS enviada'), backgroundColor: VaiaColors.danger),
    );
  }

  Future<void> _cancelarServicio(RideProvider ride) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
        title: const Text('Cancelar servicio'),
        content: const Text('Estas seguro de cancelar este servicio?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Si, cancelar', style: TextStyle(color: VaiaColors.danger)),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    final ok = await ride.cancelarServicio();
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  void _irARating() {
    if (_yaNavegoFin) return;
    _yaNavegoFin = true;
    final ride = context.read<RideProvider>();
    ride.stopPolling();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RatingScreen()));
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rideProv = context.watch<RideProvider>();
    final ride = rideProv.currentRide;

    if (ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tu viaje')),
        body: const Center(child: Text('No hay un viaje activo')),
      );
    }

    if (ride.esFinalizado) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _irARating());
    }

    final cond = ride.conductor;
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) context.read<RideProvider>().stopPolling();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // ── Mapa a pantalla completa ──
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(double.tryParse(ride.latOrigen) ?? 26.0923, double.tryParse(ride.lngOrigen) ?? -98.2789),
                  zoom: 14,
                ),
                onMapCreated: (c) {
                  _mapCtrl = c;
                  _actualizarMapa(forzar: true);
                },
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                padding: EdgeInsets.only(bottom: size.height * 0.44, top: 90),
              ),
            ),

            // ── Barra superior flotante ──
            _barraSuperior(ride),

            // ── Panel deslizable ──
            DraggableScrollableSheet(
              initialChildSize: 0.46,
              minChildSize: 0.28,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.46, 0.92],
              builder: (ctx, scrollCtrl) => _panel(scrollCtrl, ride, cond),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraSuperior(RideModel ride) {
    final conectado = context.watch<RideProvider>().conectadoWs;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              _botonCircular(
                icon: Icons.arrow_back_rounded,
                onTap: () { context.read<RideProvider>().stopPolling(); Navigator.of(context).pop(); },
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(VaiaRadius.pill),
                  boxShadow: VaiaShadows.card,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _puntoConexion(conectado),
                    const SizedBox(width: 7),
                    Text(
                      conectado ? 'Tiempo real' : 'Reconectando...',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: conectado ? VaiaColors.success : VaiaColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _botonCircular(icon: Icons.headset_mic_rounded, onTap: () => _abrirSoporte(ride.id)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _puntoConexion(bool conectado) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 9, height: 9,
        decoration: BoxDecoration(
          color: conectado ? VaiaColors.success : VaiaColors.textMuted,
          shape: BoxShape.circle,
          boxShadow: conectado ? [BoxShadow(color: VaiaColors.success.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)] : null,
        ),
      );

  Widget _botonCircular({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 20, color: VaiaColors.textPrimary)),
      ),
    );
  }

  void _abrirSoporte(int idServicio) {
    Navigator.of(context).pushNamed(AppRoutes.supportChat, arguments: {'idServicio': idServicio});
  }

  // ─── Panel inferior ───────────────────────────────────────────

  Widget _panel(ScrollController scrollCtrl, RideModel ride, dynamic cond) {
    final isCancelable = ride.esSolicitado || ride.esEnCamino;

    return Container(
      decoration: const BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Center(
            child: Container(
              width: 42, height: 5,
              decoration: BoxDecoration(color: VaiaColors.border, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 16),

          _tituloEstatus(ride),
          const SizedBox(height: 18),

          StatusTimeline(pasoActual: ride.pasoActual, cancelado: ride.cancelado, compacto: true),
          const SizedBox(height: 20),

          if (cond != null) ...[
            _tarjetaConductor(ride, cond),
            const SizedBox(height: 14),
          ] else
            _tarjetaBuscando(),

          // Codigo de inicio
          if (ride.codigoInicio != null && ride.codigoInicio!.isNotEmpty && !ride.esEnViaje && !ride.esFinalizado) ...[
            const SizedBox(height: 4),
            _tarjetaCodigo(ride.codigoInicio!),
            const SizedBox(height: 14),
          ],

          _tarjetaRuta(ride),
          const SizedBox(height: 14),

          _tarjetaTarifa(ride),
          const SizedBox(height: 14),

          if (context.watch<RideProvider>().paradas.isNotEmpty) ...[
            _tarjetaParadas(),
            const SizedBox(height: 14),
          ],

          _acciones(ride, cond),
          const SizedBox(height: 12),

          if (isCancelable)
            OutlinedButton.icon(
              onPressed: () => _cancelarServicio(context.read<RideProvider>()),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancelar servicio'),
              style: OutlinedButton.styleFrom(
                foregroundColor: VaiaColors.danger,
                side: const BorderSide(color: VaiaColors.danger),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tituloEstatus(RideModel ride) {
    final (titulo, subtitulo) = _textoEstatus(ride);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim), child: child),
      ),
      child: Column(
        key: ValueKey('${ride.estatus}-${ride.idConductor}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary, letterSpacing: -0.3)),
          const SizedBox(height: 3),
          Text(subtitulo, style: const TextStyle(fontSize: 13.5, color: VaiaColors.textSecondary, height: 1.3)),
        ],
      ),
    );
  }

  (String, String) _textoEstatus(RideModel ride) {
    if (ride.cancelado) return ('Servicio cancelado', 'El servicio fue cancelado');
    switch (ride.pasoActual) {
      case 0:
        return ('Buscando tu conductor', 'Estamos asignando la unidad mas cercana');
      case 1:
        return ('Tu conductor va en camino', '${ride.conductor?.nombreCompleto ?? 'El conductor'} llegara en unos minutos');
      case 2:
        return ('Tu conductor ha llegado', 'Comparte el codigo de inicio para comenzar');
      case 3:
        return ('Disfruta tu viaje', 'Te diriges a ${ride.direccionDestino}');
      case 4:
        return ('Viaje finalizado', 'Gracias por viajar con Vaia');
      default:
        return (ride.estatus ?? 'Servicio', ride.estatusDescripcion ?? '');
    }
  }

  Widget _tarjetaConductor(RideModel ride, dynamic cond) {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: VaiaColors.primaryGhost,
                    backgroundImage: (cond?.fotoperfil != null && cond.fotoperfil.toString().isNotEmpty)
                        ? NetworkImage(cond.fotoperfil.toString())
                        : null,
                    child: (cond?.fotoperfil == null || cond.fotoperfil.toString().isEmpty)
                        ? const Icon(Icons.person_rounded, color: VaiaColors.primary, size: 30)
                        : null,
                  ),
                  Positioned(
                    right: -2, bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: VaiaColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cond?.nombreCompleto?.isNotEmpty == true ? cond.nombreCompleto : 'Conductor',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: VaiaColors.accent),
                        const SizedBox(width: 3),
                        Text(
                          cond?.calificacion != null && cond.calificacion > 0 ? cond.calificacion.toStringAsFixed(1) : 'Nuevo',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary),
                        ),
                        if ((cond?.totalViajes ?? 0) > 0) ...[
                          const SizedBox(width: 8),
                          Container(width: 3, height: 3, decoration: const BoxDecoration(color: VaiaColors.textMuted, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text('${cond.totalViajes} viajes', style: const TextStyle(fontSize: 12, color: VaiaColors.textSecondary)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _accionCircular(Icons.call_rounded, VaiaColors.success, () => _llamar(cond?.telefono)),
              const SizedBox(width: 8),
              _accionCircular(Icons.chat_bubble_rounded, VaiaColors.primary, () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    idServicio: ride.id,
                    conductorNombre: cond?.nombreCompleto ?? 'Conductor',
                    conductorFoto: cond?.fotoperfil,
                    conductorTelefono: cond?.telefono,
                  ),
                ));
              }),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: VaiaColors.bgSubtle, borderRadius: BorderRadius.circular(VaiaRadius.md)),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: _colorDe(ride.colorHex), shape: BoxShape.circle, border: Border.all(color: VaiaColors.borderStrong)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    [
                      if (cond?.marca != null) cond.marca,
                      if (cond?.submarca != null) cond.submarca,
                      if (cond?.modelo != null) cond.modelo,
                    ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' '),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((cond?.placas ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: VaiaColors.textPrimary, borderRadius: BorderRadius.circular(6)),
                    child: Text(cond!.placas!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorDe(String? hex) {
    if (hex == null || hex.isEmpty) return VaiaColors.textMuted;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF9CA3AF);
  }

  Widget _tarjetaBuscando() {
    return _card(
      child: Row(
        children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Buscando conductor', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                SizedBox(height: 2),
                Text('Esto puede tardar unos segundos', style: TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCodigo(String codigo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [VaiaColors.primary.withValues(alpha: 0.12), VaiaColors.primary.withValues(alpha: 0.04)]),
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.vpn_key_rounded, size: 16, color: VaiaColors.primary),
              SizedBox(width: 6),
              Text('CODIGO DE INICIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: VaiaColors.primary, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 8),
          Text(codigo, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 10, color: VaiaColors.textPrimary)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _copiarCodigo(codigo),
            icon: Icon(_copiado ? Icons.check_rounded : Icons.copy_rounded, size: 16),
            label: Text(_copiado ? 'Copiado' : 'Copiar codigo'),
          ),
          const Text('Compartelo con tu conductor para iniciar el viaje',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: VaiaColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _tarjetaRuta(RideModel ride) {
    return _card(
      child: Column(
        children: [
          _renglonRuta(Icons.trip_origin, VaiaColors.success, 'Origen', ride.direccionOrigen),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Row(children: [Container(width: 2, height: 18, color: VaiaColors.border)]),
          ),
          _renglonRuta(Icons.location_on_rounded, VaiaColors.danger, 'Destino', ride.direccionDestino),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _metrica(Icons.route_rounded, '${(ride.distanciaMetros / 1000).toStringAsFixed(1)} km', 'Distancia'),
              _separador(),
              _metrica(Icons.timer_rounded, ride.duracionSegundos != null && ride.duracionSegundos! > 0 ? '${(ride.duracionSegundos! / 60).ceil()} min' : '--', 'Duracion'),
              _separador(),
              _metrica(Icons.local_taxi_rounded, (ride.tipoviaje ?? '--'), 'Tipo'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _renglonRuta(IconData icon, Color color, String label, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: VaiaColors.textMuted, letterSpacing: 0.4)),
              Text(valor.isEmpty ? '--' : valor, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metrica(IconData icon, String valor, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: VaiaColors.primary),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 10.5, color: VaiaColors.textMuted)),
        ],
      ),
    );
  }

  Widget _separador() => Container(width: 1, height: 30, color: VaiaColors.border);

  Widget _tarjetaTarifa(RideModel ride) {
    final monto = ride.montoActual;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: ride.esEnViaje ? VaiaColors.primaryGradient : null,
        color: ride.esEnViaje ? null : VaiaColors.bgSubtle,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
      ),
      child: Column(
        children: [
          Text(
            ride.esFinalizado ? 'Total pagado' : ride.esEnViaje ? 'Cobro en tiempo real' : 'Costo estimado',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ride.esEnViaje ? Colors.white70 : VaiaColors.textSecondary, letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: monto, end: monto),
            duration: const Duration(milliseconds: 500),
            builder: (_, v, __) => Text(
              '\$${v.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: ride.esEnViaje ? Colors.white : VaiaColors.textPrimary, letterSpacing: -0.5),
            ),
          ),
          if (ride.esEnViaje) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_outlined, size: 15, color: Colors.white70),
                const SizedBox(width: 6),
                Text('Se actualiza al avanzar', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ],
          if (ride.esFinalizado || (ride.costoFinal ?? 0) > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pagarEnLinea(ride.id),
                icon: const Icon(Icons.credit_card_rounded, size: 18),
                label: const Text('Pagar en linea (MercadoPago / PayPal)'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaParadas() {
    final paradas = context.watch<RideProvider>().paradas;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alt_route_rounded, size: 17, color: VaiaColors.accent),
              const SizedBox(width: 8),
              Text('Paradas (${paradas.where((p) => p.completada).length}/${paradas.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          ...paradas.map((p) => Padding(
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
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _acciones(RideModel ride, dynamic cond) {
    return Row(
      children: [
        Expanded(
          child: _accionGrande(
            icon: Icons.support_agent_rounded,
            label: 'Soporte',
            color: VaiaColors.primary,
            onTap: () => _abrirSoporte(ride.id),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _accionGrande(
            icon: Icons.report_problem_rounded,
            label: 'Incidente',
            color: VaiaColors.accent,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportIncidentScreen(idServicio: ride.id))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _botonSos(onCompletar: () => _sos(context.read<RideProvider>(), ride.id))),
      ],
    );
  }

  Widget _accionGrande({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(VaiaRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accionCircular(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: color)),
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

  Widget _botonSos({required Future<void> Function() onCompletar}) {
    return _SosButton(onCompletar: onCompletar);
  }
}

/// Boton SOS que exige mantener presionado para activar la alerta.
class _SosButton extends StatefulWidget {
  final Future<void> Function() onCompletar;
  const _SosButton({required this.onCompletar});
  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton> {
  Timer? _timer;
  double _progreso = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciar() {
    _timer?.cancel();
    _progreso = 0;
    const pasos = 18; // ~1.8 s
    var i = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      i++;
      setState(() => _progreso = i / pasos);
      if (i >= pasos) {
        t.cancel();
        HapticFeedback.heavyImpact();
        widget.onCompletar();
        setState(() => _progreso = 0);
      }
    });
  }

  void _cancelar() {
    _timer?.cancel();
    if (mounted) setState(() => _progreso = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _iniciar(),
      onTapUp: (_) => _cancelar(),
      onTapCancel: _cancelar,
      child: Container(
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: VaiaColors.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(VaiaRadius.md),
          border: Border.all(color: VaiaColors.danger, width: 1.4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_progreso > 0)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progreso,
                  child: Container(
                    decoration: BoxDecoration(
                      color: VaiaColors.danger.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(VaiaRadius.md),
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sos_rounded, size: 24, color: VaiaColors.danger),
                const SizedBox(height: 2),
                Text('SOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: VaiaColors.danger)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

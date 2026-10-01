import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/conductor_model.dart';
import '../../models/promocion_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/ride_provider.dart';
import '../../widgets/location_gate.dart';
import '../../services/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/vaia_widgets.dart';
import 'service_request_screen.dart';
import 'service_status_screen.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  bool _locationLoading = true;
  bool _mapError = false;

  // Unidades cercanas
  BitmapDescriptor? _carIcon;
  final Map<int, LatLng> _driverPos = {};
  final Map<int, double> _driverBearing = {};
  Timer? _driversTimer;

  @override
  void initState() {
    super.initState();
    _initLocation();
    context.read<ProfileProvider>().cargarFavoritos();
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      context.read<RideProvider>().iniciarPresencia(auth.userId);
      // Reanuda el servicio en curso si la app se cerro durante un viaje.
      WidgetsBinding.instance.addPostFrameCallback((_) => _restaurarServicio(auth.userId));
    }
    // Refrescar unidades cercanas cada 10 s mientras el pasajero esta en Inicio
    _driversTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadDrivers());
    _cargarIconoCarrito();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarCorreoPendiente());
    WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarPromoDelDia());
  }

  bool _promoMostrada = false;

  /// Muestra una promocion activa aleatoria al ingresar a la app.
  Future<void> _mostrarPromoDelDia() async {
    if (_promoMostrada || !context.read<AuthProvider>().isLoggedIn) return;
    final profile = context.read<ProfileProvider>();
    await profile.cargarPromociones();
    if (!mounted) return;
    final activas = profile.promociones.where((p) => p.activo).toList();
    if (activas.isEmpty) return;
    final promo = activas[math.Random().nextInt(activas.length)];
    _promoMostrada = true;
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _promoDialog(promo);
  }

  void _promoDialog(PromocionModel p) {
    Uint8List? img;
    if (p.imgBase64 != null && p.imgBase64!.isNotEmpty) {
      try { img = base64Decode(p.imgBase64!); } catch (_) {}
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (img != null)
              Image.memory(img, height: 190, width: double.infinity, fit: BoxFit.cover)
            else
              Container(
                height: 150,
                width: double.infinity,
                decoration: const BoxDecoration(gradient: VaiaColors.heroGradient),
                child: const Center(child: Icon(Icons.local_offer_rounded, color: Colors.white, size: 52)),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Promocion para ti', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: VaiaColors.primary, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(p.titulo ?? 'Promocion', textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
                  if ((p.descripcion ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(p.descripcion!, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: VaiaColors.textSecondary, height: 1.4)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(context, '/promotions');
                      },
                      child: const Text('Ver promociones'),
                    ),
                  ),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Si el pasajero tenia un servicio en curso, lo reanuda al reabrir la app.
  Future<void> _restaurarServicio(int idPasajero) async {
    final ride = context.read<RideProvider>();
    if (ride.currentRide != null) return;
    final ok = await ride.restaurarServicioActivo(idPasajero);
    if (!mounted || !ok) return;
    final estatus = (ride.currentRide?.estatus ?? '').toLowerCase();
    if (estatus == 'finalizado' || estatus.contains('cancel')) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ServiceStatusScreen()),
    );
  }

  /// Al ingresar, si el correo aun no esta verificado se solicita validarlo
  /// (o corregirlo) sin bloquear el uso de la app.
  Future<void> _verificarCorreoPendiente() async {
    final auth = context.read<AuthProvider>();
    if (!mounted || !auth.isLoggedIn || auth.correoConfirmado) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
    );
  }

  Future<void> _cargarIconoCarrito() async {
    try {
      final data = await rootBundle.load('assets/images/car.png');
      final bd = BitmapDescriptor.fromBytes(data.buffer.asUint8List());
      if (mounted) setState(() => _carIcon = bd);
    } catch (_) {}
  }

  @override
  void dispose() {
    _driversTimer?.cancel();
    context.read<RideProvider>().detenerPresencia();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationLoading = false);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationLoading = false);
        return;
      }
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        _locationLoading = false;
      });
      _updateUserMarker(pos);
      _loadDrivers();
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _updateUserMarker(Position pos) {
    try {
      final marker = Marker(
        markerId: const MarkerId('current_user'),
        position: LatLng(pos.latitude, pos.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Tu ubicacion'),
      );
      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'current_user');
        _markers.add(marker);
      });
      _animateTo(pos.latitude, pos.longitude);
    } catch (_) {
      setState(() => _mapError = true);
    }
  }

  void _animateTo(double lat, double lng) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15));
  }

  Future<void> _loadDrivers() async {
    if (_currentPosition == null) return;
    final rideProv = context.read<RideProvider>();
    await rideProv.buscarConductores(
      lat: _currentPosition!.latitude.toString(),
      lng: _currentPosition!.longitude.toString(),
    );
    if (!mounted) return;
    _updateDriverMarkers(rideProv.conductoresDisponibles);
  }

  void _updateDriverMarkers(List<ConductorModel> drivers) {
    try {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value.startsWith('driver_'));
        for (final d in drivers) {
          if (d.lat == null || d.lng == null) continue;
          final lat = double.tryParse(d.lat!);
          final lng = double.tryParse(d.lng!);
          if (lat == null || lng == null) continue;
          final nueva = LatLng(lat, lng);

          // Calcular rumbo (bearing) para rotar el carrito, como Uber/Didi
          final anterior = _driverPos[d.id];
          if (anterior != null && (anterior.latitude != lat || anterior.longitude != lng)) {
            _driverBearing[d.id] = _calcularBearing(anterior, nueva);
          }
          _driverPos[d.id] = nueva;

          final dist = d.distanciaKm != null ? 'a ${d.distanciaKm!.toStringAsFixed(1)} km' : '';
          final unidad = d.unidad ?? '';
          final snippet = [unidad, dist].where((s) => s.isNotEmpty).join(' - ');

          _markers.add(
            Marker(
              markerId: MarkerId('driver_${d.id}'),
              position: nueva,
              rotation: _driverBearing[d.id] ?? 0,
              flat: true,
              anchor: const Offset(0.5, 0.5),
              icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(title: d.nombreCompleto, snippet: snippet),
            ),
          );
        }
      });
    } catch (_) {
      setState(() => _mapError = true);
    }
  }

  /// Rumbo en grados desde el punto `a` hacia el punto `b` (0 = norte).
  double _calcularBearing(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180.0 / math.pi;
    return (brng + 360.0) % 360.0;
  }

  void _navigateToServiceRequest() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obteniendo ubicacion...')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceRequestScreen(
          currentLat: _currentPosition!.latitude,
          currentLng: _currentPosition!.longitude,
        ),
      ),
    );
  }

  static const _urlAppConductor = 'https://play.google.com/store/apps/details?id=prozoft.com.vaiaconductor&hl=es_MX';

  void _showMenuSheet() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        expand: false,
        builder: (ctx2, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 44, height: 5,
                  decoration: BoxDecoration(color: VaiaColors.border, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 18),
              _menuHeader(user),
              const SizedBox(height: 20),
              _menuGrid(ctx),
              const SizedBox(height: 18),
              _unirseConductor(ctx),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<AuthProvider>().logout();
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VaiaColors.danger,
                    side: const BorderSide(color: VaiaColors.danger),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(S.t(context, 'Cerrar sesion', 'Log out')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuHeader(dynamic user) {
    final nombre = (user?.nombre ?? '').toString();
    final foto = user?.fotoperfil as String?;
    final contacto = (user?.correo ?? '').toString().isNotEmpty ? user.correo.toString() : (user?.telefono ?? '').toString();
    final iniciales = nombre.trim().isEmpty
        ? '?'
        : nombre.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0]).join().toUpperCase();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: VaiaColors.primaryGradient),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: VaiaColors.surface,
            backgroundImage: (foto != null && foto.isNotEmpty) ? NetworkImage(foto) : null,
            child: (foto == null || foto.isEmpty)
                ? Text(iniciales, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: VaiaColors.primary))
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${S.t(context, 'Hola', 'Hi')}, ${nombre.isEmpty ? S.t(context, 'viajero', 'traveler') : nombre}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(contacto, style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: VaiaColors.textMuted),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _menuGrid(BuildContext ctx) {
    final items = <(IconData, String, Color, VoidCallback)>[
      (Icons.person_rounded, S.t(context, 'Mi perfil', 'My profile'), VaiaColors.primary, () => Navigator.pushNamed(context, '/profile')),
      (Icons.star_rounded, S.t(context, 'Favoritos', 'Favorites'), VaiaColors.accent, () => Navigator.pushNamed(context, '/favorites')),
      (Icons.history_rounded, S.t(context, 'Historial', 'History'), VaiaColors.info, () => Navigator.pushNamed(context, '/history')),
      (Icons.notifications_rounded, S.t(context, 'Notificaciones', 'Notifications'), VaiaColors.info, () => Navigator.pushNamed(context, '/notifications')),
      (Icons.local_offer_rounded, S.t(context, 'Promociones', 'Promotions'), VaiaColors.danger, () => Navigator.pushNamed(context, '/promotions')),
      (Icons.event_available_rounded, S.t(context, 'Programados', 'Scheduled'), VaiaColors.success, () => Navigator.pushNamed(context, '/scheduled-rides')),
      (Icons.support_agent_rounded, S.t(context, 'Soporte', 'Support'), VaiaColors.primaryDark, () {
        final ride = context.read<RideProvider>();
        Navigator.pushNamed(context, '/support-chat', arguments: {'idServicio': ride.currentRide?.id});
      }),
      (Icons.settings_rounded, S.t(context, 'Ajustes', 'Settings'), VaiaColors.textSecondary, () => Navigator.pushNamed(context, '/settings')),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 10,
      childAspectRatio: 0.78,
      children: items.map((it) {
        final (icon, label, color, onTap) = it;
        return InkWell(
          borderRadius: BorderRadius.circular(VaiaRadius.md),
          onTap: () { Navigator.of(ctx).pop(); onTap(); },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, maxLines: 2,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _unirseConductor(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: VaiaColors.heroGradient,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.t(context, 'Tienes un auto?', 'Have a car?'),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(S.t(context, 'Unete como conductor y genera ingresos con Vaia.', 'Join as a driver and earn with Vaia.'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _abrirAppConductor(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: VaiaColors.primaryDark, padding: const EdgeInsets.symmetric(horizontal: 14)),
            child: Text(S.t(context, 'Unirme', 'Join')),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirAppConductor(BuildContext ctx) async {
    final uri = Uri.parse(_urlAppConductor);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la tienda de aplicaciones'), backgroundColor: VaiaColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final rideProv = context.watch<RideProvider>();
    final themeProv = context.watch<ThemeProvider>();

    return LocationGate(
      child: Scaffold(
      body: Stack(
        children: [
          _buildMapArea(),
          if (_locationLoading)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(VaiaRadius.pill),
                    boxShadow: VaiaShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: VaiaColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Obteniendo ubicacion...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: _floatingButton(
              icon: Icons.menu_rounded,
              onTap: _showMenuSheet,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: Row(
              children: [
                _floatingButton(
                  icon: themeProv.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  onTap: () => themeProv.toggleTheme(),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(VaiaRadius.pill),
                    boxShadow: VaiaShadows.card,
                  ),
                  child: Row(
                    children: [
                      const VaiaLogo(size: 18, color: VaiaColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Vaia',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: VaiaColors.primary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: rideProv.conectadoWs ? 'Conectado en tiempo real' : 'Reconectando...',
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: rideProv.conectadoWs ? VaiaColors.success : VaiaColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomPanel(profile, rideProv)),
          Positioned(
            bottom: 250,
            right: 16,
            child: Column(
              children: [
                _floatingButton(
                  icon: Icons.my_location_rounded,
                  onTap: () {
                    if (_currentPosition != null) {
                      _animateTo(_currentPosition!.latitude, _currentPosition!.longitude);
                    }
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'sos',
                  backgroundColor: VaiaColors.danger,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SOS - Alarma enviada')),
                    );
                  },
                  child: const Icon(Icons.shield_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _floatingButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(VaiaRadius.md),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: VaiaColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildMapArea() {
    if (_mapError || _currentPosition == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: VaiaColors.heroGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map_outlined,
                size: 80,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                _currentPosition == null
                    ? 'Ubicacion no disponible'
                    : 'Mapa no disponible',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Solicita un viaje para empezar',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      );
    }
    try {
      return GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 15,
        ),
        onMapCreated: (ctrl) => _mapController = ctrl,
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        compassEnabled: true,
        mapToolbarEnabled: false,
        onTap: (_) {},
      );
    } catch (_) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 80, color: VaiaColors.textMuted),
              const SizedBox(height: 16),
              Text(
                'Mapa no disponible',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildBottomPanel(ProfileProvider profile, RideProvider rideProv) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _navigateToServiceRequest,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(VaiaRadius.md),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: VaiaColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'A donde vamos?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: VaiaColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (profile.favoritos.isNotEmpty) ...[
                const SizedBox(height: 14),
                _favoritosList(profile),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _quickAction(Icons.person_outline_rounded, 'Perfil',
                      () => Navigator.pushNamed(context, '/profile')),
                  _quickAction(Icons.star_outline_rounded, 'Favoritos',
                      () => Navigator.pushNamed(context, '/favorites')),
                  _quickAction(Icons.history_rounded, 'Historial',
                      () => Navigator.pushNamed(context, '/history')),
                  _quickAction(Icons.local_offer_outlined, 'Promos',
                      () => Navigator.pushNamed(context, '/promotions'),
                      accent: VaiaColors.accent),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _favoritosList(ProfileProvider profile) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profile.favoritos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final f = profile.favoritos[i];
          return Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(VaiaRadius.pill),
            child: InkWell(
              onTap: _navigateToServiceRequest,
              borderRadius: BorderRadius.circular(VaiaRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(VaiaRadius.pill),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: VaiaColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      f.nombre,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap, {Color? accent}) {
    final c = accent ?? VaiaColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(VaiaRadius.md),
                ),
                child: Icon(icon, color: c, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: VaiaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
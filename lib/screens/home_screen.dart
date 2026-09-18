import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/conductor_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/vaia_widgets.dart';
import 'service_request_screen.dart';
import 'login_screen.dart';

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
    }
    // Refrescar unidades cercanas cada 10 s mientras el pasajero esta en Inicio
    _driversTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadDrivers());
    _cargarIconoCarrito();
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

  void _showMenuSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
              const SizedBox(height: 12),
              _menuTile(ctx, Icons.person_outline_rounded, 'Mi Perfil',
                  () => Navigator.pushNamed(context, '/profile')),
              _menuTile(ctx, Icons.star_outline_rounded, 'Favoritos',
                  () => Navigator.pushNamed(context, '/favorites')),
              _menuTile(ctx, Icons.history_rounded, 'Historial',
                  () => Navigator.pushNamed(context, '/history')),
              _menuTile(ctx, Icons.confirmation_number_outlined, 'Promociones',
                  () => Navigator.pushNamed(context, '/promotions')),
              _menuTile(ctx, Icons.schedule_rounded, 'Viajes programados',
                  () => Navigator.pushNamed(context, '/scheduled-rides')),
              _menuTile(ctx, Icons.support_agent_rounded, 'Soporte en linea', () {
                final ride = context.read<RideProvider>();
                if (ride.currentRide != null) {
                  Navigator.pushNamed(context, '/support-chat',
                      arguments: {'idServicio': ride.currentRide!.id});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('El soporte esta disponible durante un servicio activo'),
                    backgroundColor: VaiaColors.warning,
                  ));
                }
              }),
              _menuTile(ctx, Icons.settings_outlined, 'Configuracion',
                  () => Navigator.pushNamed(context, '/settings')),
              const Divider(height: 1),
              _menuTile(ctx, Icons.logout_rounded, 'Cerrar sesion', () {
                context.read<AuthProvider>().logout();
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(BuildContext ctx, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: VaiaColors.textSecondary),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: VaiaColors.textMuted),
      onTap: () {
        Navigator.of(ctx).pop();
        onTap();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.sm)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final rideProv = context.watch<RideProvider>();
    final themeProv = context.watch<ThemeProvider>();

    return Scaffold(
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
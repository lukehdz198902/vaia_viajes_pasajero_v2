import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/conductor_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/theme_provider.dart';
import 'service_request_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadDrivers();
    context.read<ProfileProvider>().cargarFavoritos();
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
          if (d.lat != null && d.lng != null) {
            _markers.add(
              Marker(
                markerId: MarkerId('driver_${d.id}'),
                position: LatLng(double.parse(d.lat!), double.parse(d.lng!)),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                infoWindow: InfoWindow(title: d.nombreCompleto, snippet: '${d.unidad ?? ''} - ${d.placas ?? ''}'),
              ),
            );
          }
        }
      });
    } catch (_) {
      setState(() => _mapError = true);
    }
  }

  void _navigateToServiceRequest() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Obteniendo ubicacion...')));
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
    final isDark = context.read<ThemeProvider>().isDarkMode;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: isDark ? AppTheme.darkBorder : AppTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              _menuTile(ctx, Icons.person_outline, 'Mi Perfil', () => Navigator.pushNamed(context, '/profile')),
              _menuTile(ctx, Icons.star_outline, 'Favoritos', () => Navigator.pushNamed(context, '/favorites')),
              _menuTile(ctx, Icons.history, 'Historial', () => Navigator.pushNamed(context, '/history')),
              _menuTile(ctx, Icons.confirmation_number_outlined, 'Promociones', () => Navigator.pushNamed(context, '/promotions')),
              _menuTile(ctx, Icons.support_agent_outlined, 'Soporte', () => _showComingSoon(context)),
              const Divider(),
              _menuTile(ctx, Icons.logout, 'Cerrar Sesion', () {
                context.read<AuthProvider>().logout();
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SizedBox.shrink()),
                  (route) => false,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Proximamente...'), backgroundColor: AppTheme.primary),
    );
  }

  Widget _menuTile(BuildContext ctx, IconData icon, String title, VoidCallback onTap) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    return ListTile(
      leading: Icon(icon, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textDark),
      title: Text(title, style: TextStyle(fontSize: 15, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textDark)),
      trailing: Icon(Icons.chevron_right, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
      onTap: () {
        Navigator.of(ctx).pop();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final rideProv = context.watch<RideProvider>();
    final themeProv = context.watch<ThemeProvider>();
    final isDark = themeProv.isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          _buildMapArea(isDark),
          if (_locationLoading)
            Positioned(
              top: 60, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Text('Obteniendo ubicacion...', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMedium)),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 50, left: 16,
            child: GestureDetector(
              onTap: _showMenuSheet,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                ),
                child: Icon(Icons.menu, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textDark),
              ),
            ),
          ),
          Positioned(
            top: 50, right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => themeProv.toggleTheme(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                    ),
                    child: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: isDark ? AppTheme.secondary : AppTheme.textDark),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car_rounded, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Vaia Viajes',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomPanel(profile, rideProv, isDark)),
          Positioned(
            bottom: 220, right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'location',
                  backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                  onPressed: () {
                    if (_currentPosition != null) {
                      _animateTo(_currentPosition!.latitude, _currentPosition!.longitude);
                    }
                  },
                  child: Icon(Icons.my_location, color: isDark ? AppTheme.darkTextPrimary : AppTheme.textDark),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'sos',
                  backgroundColor: AppTheme.danger,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SOS - Alarma enviada'), backgroundColor: Colors.red),
                    );
                  },
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapArea(bool isDark) {
    if (_mapError || _currentPosition == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A237E), const Color(0xFF121212)]
                : [AppTheme.primaryLight.withValues(alpha: 0.3), AppTheme.bgLight],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 80, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
              const SizedBox(height: 16),
              Text(
                _currentPosition == null
                    ? 'Ubicacion no disponible'
                    : 'Mapa no disponible',
                style: TextStyle(fontSize: 18, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMedium),
              ),
              const SizedBox(height: 8),
              Text(
                'Usa el boton de abajo para solicitar un viaje',
                style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
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
        width: double.infinity, height: double.infinity,
        color: isDark ? AppTheme.darkBg : AppTheme.bgLight,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 80, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textLight),
              const SizedBox(height: 16),
              Text('Mapa no disponible en esta plataforma',
                style: TextStyle(fontSize: 18, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMedium)),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildBottomPanel(ProfileProvider profile, RideProvider rideProv, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
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
                width: 40, height: 4,
                decoration: BoxDecoration(color: isDark ? AppTheme.darkBorder : AppTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _navigateToServiceRequest,
                  icon: const Icon(Icons.search),
                  label: const Text('A donde vamos?', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              if (profile.favoritos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: profile.favoritos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final f = profile.favoritos[i];
                      return ActionChip(
                        avatar: const Icon(Icons.star, size: 16, color: AppTheme.secondary),
                        label: Text(f.nombre, style: const TextStyle(fontSize: 12)),
                        onPressed: _navigateToServiceRequest,
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _quickAction(Icons.person_outline, 'Perfil', () => Navigator.pushNamed(context, '/profile')),
                  _quickAction(Icons.star_outline, 'Favoritos', () => Navigator.pushNamed(context, '/favorites')),
                  _quickAction(Icons.history, 'Historial', () => Navigator.pushNamed(context, '/history')),
                  _quickAction(Icons.confirmation_number_outlined, 'Promos', () => Navigator.pushNamed(context, '/promotions'), AppTheme.secondary, isDark),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap, [Color? iconColor, bool isDark = false]) {
    final color = iconColor ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.textDark);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.bgLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMedium, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

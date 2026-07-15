import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/conductor_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/ride_provider.dart';
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
  }

  void _updateUserMarker(Position pos) {
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
  }

  void _navigateToServiceRequest() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Obteniendo ubicacion...')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ServiceRequestScreen(currentLat: _currentPosition!.latitude, currentLng: _currentPosition!.longitude),
      ),
    );
  }

  void _showMenuSheet() {
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              _menuTile(ctx, Icons.person_outline, 'Mi Perfil', () {}),
              _menuTile(ctx, Icons.star_outline, 'Favoritos', () {}),
              _menuTile(ctx, Icons.history, 'Historial', () {}),
              _menuTile(ctx, Icons.confirmation_number_outlined, 'Promociones', () {}),
              _menuTile(ctx, Icons.support_agent_outlined, 'Soporte', () {}),
              const Divider(),
              _menuTile(ctx, Icons.logout, 'Cerrar Sesion', () {
                context.read<AuthProvider>().logout();
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SizedBox.shrink() /* LoginScreen */),
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
      leading: Icon(icon, color: AppTheme.textDark),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textLight),
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

    return Scaffold(
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
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
                ),
          if (_locationLoading)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Text('Obteniendo ubicacion...', style: TextStyle(fontSize: 12, color: AppTheme.textMedium)),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 50,
            left: 16,
            child: GestureDetector(
              onTap: _showMenuSheet,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                ),
                child: const Icon(Icons.menu, color: AppTheme.textDark),
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                  ),
                ],
              ),
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomPanel(profile, rideProv)),
          Positioned(
            bottom: 220,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'location',
                  backgroundColor: Colors.white,
                  onPressed: () {
                    if (_currentPosition != null) {
                      _animateTo(_currentPosition!.latitude, _currentPosition!.longitude);
                    }
                  },
                  child: Icon(Icons.my_location, color: AppTheme.textDark),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'sos',
                  backgroundColor: AppTheme.danger,
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('SOS - Alarma enviada'), backgroundColor: Colors.red));
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

  Widget _buildBottomPanel(ProfileProvider profile, RideProvider rideProv) {
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
                        avatar: const Icon(Icons.star, size: 16),
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
                  _quickAction(Icons.person_outline, 'Perfil', () {}),
                  _quickAction(Icons.star_outline, 'Favoritos', () {}),
                  _quickAction(Icons.history, 'Historial', () {}),
                  _quickAction(Icons.confirmation_number_outlined, 'Promos', () {}),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppTheme.bgLight, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppTheme.textDark, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.textMedium, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

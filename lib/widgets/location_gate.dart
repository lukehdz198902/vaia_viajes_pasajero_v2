import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../config/theme.dart';

/// Bloquea el uso de la app hasta que el servicio de ubicacion y el permiso
/// esten activos. Si el usuario los desactiva mientras usa la app, vuelve a
/// mostrarse el aviso y se le explica por que se requiere.
class LocationGate extends StatefulWidget {
  final Widget child;
  const LocationGate({super.key, required this.child});

  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate> with WidgetsBindingObserver {
  bool? _ok; // null = verificando; false = bloqueado
  bool _servicioOff = false;
  bool _permisoOff = false;
  bool _pidioPermiso = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificar(solicitar: true);
    // Revision continua: detecta si desactivan el GPS o el permiso en uso.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _verificar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verificar();
  }

  Future<void> _verificar({bool solicitar = false}) async {
    bool servicio = true;
    bool permiso = true;
    try {
      servicio = await Geolocator.isLocationServiceEnabled();
      if (servicio) {
        var p = await Geolocator.checkPermission();
        if (p == LocationPermission.denied && solicitar && !_pidioPermiso) {
          _pidioPermiso = true;
          p = await Geolocator.requestPermission();
        }
        permiso = p == LocationPermission.always || p == LocationPermission.whileInUse;
      }
    } catch (_) {
      servicio = false;
    }
    final ok = servicio && permiso;
    if (!mounted) return;
    if (_ok != ok) {
      setState(() {
        _ok = ok;
        _servicioOff = !servicio;
        _permisoOff = !permiso;
      });
    }
  }

  Future<void> _abrirAjustes() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {}
    if (mounted) _verificar();
  }

  @override
  Widget build(BuildContext context) {
    // Mientras se verifica o si todo esta en orden, no bloquea.
    if (_ok != false) return widget.child;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 130, height: 130),
                const SizedBox(height: 24),
                const Icon(Icons.location_off_rounded, color: VaiaColors.danger, size: 42),
                const SizedBox(height: 12),
                Text(
                  _servicioOff ? 'Activa tu ubicacion' : 'Permiso de ubicacion requerido',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  _servicioOff
                      ? 'Vaia necesita tu ubicacion para mostrar el mapa, encontrar conductores cerca y darte seguimiento durante el viaje. Activa el GPS para continuar.'
                      : 'Para usar Vaia debes permitir el acceso a tu ubicacion. Abre los ajustes y concede el permiso "Mientras uso la app".',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.75), height: 1.45),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _abrirAjustes,
                    icon: const Icon(Icons.settings_rounded),
                    label: Text(_servicioOff ? 'Activar ubicacion' : 'Abrir ajustes'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _verificar(solicitar: true),
                  child: Text('Ya la active, reintentar', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

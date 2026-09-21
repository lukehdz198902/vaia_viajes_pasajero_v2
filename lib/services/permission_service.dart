import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Definicion de un permiso/requisito para las pantallas de onboarding.
class PermisoDef {
  final String id;
  final IconData icono;
  final Color color;
  final String titulo;
  final String descripcion;
  final List<String> puntos;
  final Permission? permiso;
  final bool obligatorio;
  final bool soloAviso;

  const PermisoDef({
    required this.id,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.descripcion,
    required this.puntos,
    this.permiso,
    this.obligatorio = false,
    this.soloAviso = false,
  });
}

/// Permisos que requiere la app del pasajero, en orden de solicitud.
class PermissionService {
  static List<PermisoDef> pasajero() => const [
        PermisoDef(
          id: 'notificaciones',
          icono: Icons.notifications_active_rounded,
          color: Color(0xFFF59E0B),
          titulo: 'Notificaciones',
          descripcion: 'Te avisamos cuando tu unidad este en camino.',
          puntos: [
            'Recibe el aviso cuando se asigne tu conductor',
            'Enterate cuando tu unidad llegue al punto de recogida',
          ],
          permiso: Permission.notification,
          obligatorio: true,
        ),
        PermisoDef(
          id: 'ubicacion',
          icono: Icons.my_location_rounded,
          color: Color(0xFF14B8A6),
          titulo: 'Ubicacion',
          descripcion: 'Usamos tu ubicacion para recogerte y mostrarte unidades cercanas.',
          puntos: [
            'Elige tu origen con un toque',
            'Ve las unidades disponibles cerca de ti',
          ],
          permiso: Permission.location,
          obligatorio: true,
        ),
        PermisoDef(
          id: 'camara',
          icono: Icons.photo_camera_rounded,
          color: Color(0xFF8B5CF6),
          titulo: 'Camara',
          descripcion: 'Para que puedas agregar tu foto de perfil.',
          puntos: [
            'Toma o elige tu foto de perfil',
            'Da mas confianza a tu conductor',
          ],
          permiso: Permission.camera,
        ),
        PermisoDef(
          id: 'telefono',
          icono: Icons.phone_in_talk_rounded,
          color: Color(0xFFEC4899),
          titulo: 'Llamadas',
          descripcion: 'Para comunicarte con tu conductor durante el servicio.',
          puntos: [
            'Llama al conductor desde la app',
            'Coordina el punto de encuentro',
          ],
          permiso: Permission.phone,
        ),
      ];

  static Future<PermissionStatus> estado(PermisoDef def) async {
    if (def.permiso == null) return PermissionStatus.granted;
    try {
      return await def.permiso!.status;
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  static Future<bool> solicitar(PermisoDef def) async {
    if (def.permiso == null) return true;
    try {
      final r = await def.permiso!.request();
      return r.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<void> abrirAjustes() => openAppSettings();
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/servicio_programado_model.dart';
import '../providers/ride_provider.dart';
import '../widgets/vaia_widgets.dart';
import 'schedule_ride_screen.dart';

class ScheduledRidesScreen extends StatefulWidget {
  const ScheduledRidesScreen({super.key});

  @override
  State<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends State<ScheduledRidesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RideProvider>().cargarProgramados();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Viajes programados'),
      ),
      body: RefreshIndicator(
        color: VaiaColors.primary,
        onRefresh: () => context.read<RideProvider>().cargarProgramados(),
        child: ride.loading && ride.programados.isEmpty
            ? const Center(child: CircularProgressIndicator(color: VaiaColors.primary))
            : ride.programados.isEmpty
                ? _buildVacio()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: ride.programados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _card(ride.programados[i]),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: VaiaColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Programar viaje',
        onPressed: () async {
          final creado = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const ScheduleRideScreen()),
          );
          if (creado == true && mounted) {
            context.read<RideProvider>().cargarProgramados();
          }
        },
      ),
    );
  }

  Widget _buildVacio() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        const Icon(Icons.event_available_rounded, size: 72, color: VaiaColors.textMuted),
        const SizedBox(height: 16),
        Center(child: Text('Sin viajes programados', style: Theme.of(context).textTheme.titleMedium)),
        const SizedBox(height: 6),
        Center(
          child: Text('Programa un viaje y te asignaremos un conductor\nen automatico',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _card(ServicioProgramadoModel p) {
    final fecha = _parseFecha(p.fechaProgramada);
    final activo = p.estaActivo;
    final color = activo ? VaiaColors.primary : VaiaColors.textMuted;

    return VaiaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.event_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fecha, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    VaiaBadge(
                      label: p.estado,
                      color: activo ? VaiaColors.primary : VaiaColors.textMuted,
                      icon: activo ? Icons.check_circle_outline : Icons.cancel_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ruta(Icons.my_location_rounded, p.direccionOrigen, VaiaColors.success),
          const SizedBox(height: 6),
          _ruta(Icons.location_on_rounded, p.direccionDestino, VaiaColors.danger),
          if (p.yaGeneroServicio) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: VaiaColors.success.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, size: 14, color: VaiaColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Servicio #${p.idServicioGenerado} generado - buscando conductor',
                        style: const TextStyle(fontSize: 11, color: VaiaColors.success, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          if (activo) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelar(p),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Cancelar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VaiaColors.danger,
                      side: const BorderSide(color: VaiaColors.danger),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _ruta(IconData icon, String texto, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  void _cancelar(ServicioProgramadoModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar programado'),
        content: Text('¿Cancelar el viaje programado para ${_parseFecha(p.fechaProgramada)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await context.read<RideProvider>().cancelarProgramado(p.id, motivo: 'Cancelado por el pasajero');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Viaje programado cancelado' : 'No se pudo cancelar'),
                  backgroundColor: ok ? VaiaColors.success : VaiaColors.danger,
                ));
              }
            },
            child: const Text('Si, cancelar', style: TextStyle(color: VaiaColors.danger)),
          ),
        ],
      ),
    );
  }

  String _parseFecha(String iso) {
    if (iso.isEmpty) return '--';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat("EEEE d 'de' MMMM, hh:mm a", 'es').format(d);
    } catch (_) {
      return iso;
    }
  }
}
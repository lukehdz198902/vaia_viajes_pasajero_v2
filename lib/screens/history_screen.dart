import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/ride_model.dart';
import '../../config/theme.dart';

/// Historial de viajes del pasajero con filtro por mes y año (por defecto el
/// mes actual) y resumen del periodo.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  late int _mes;
  late int _anio;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mes = hoy.month;
    _anio = hoy.year;
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  (DateTime, DateTime) get _rango => (
        DateTime(_anio, _mes, 1),
        DateTime(_anio, _mes + 1, 0, 23, 59, 59),
      );

  Future<void> _cargar() async {
    final (fi, ff) = _rango;
    await context.read<RideProvider>().cargarHistorial(tamano: 100, fi: fi, ff: ff);
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de viajes')),
      body: Column(
        children: [
          _selector(),
          _resumen(ride.resumenHistorial),
          Expanded(
            child: ride.loading
                ? const Center(child: CircularProgressIndicator())
                : ride.historial.isEmpty
                    ? _vacio()
                    : RefreshIndicator(
                        color: VaiaColors.primary,
                        onRefresh: _cargar,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: ride.historial.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _card(ride.historial[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _selector() {
    final anios = List<int>.generate(DateTime.now().year - 2022, (i) => DateTime.now().year - i);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: VaiaColors.surface,
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 18, color: VaiaColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: _dropdown<int>(value: _mes, items: {
            for (var m = 1; m <= 12; m++) m: _meses[m - 1]
          }, onChanged: (v) { setState(() => _mes = v!); _cargar(); })),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: _dropdown<int>(value: _anio, items: {
            for (final a in anios) a: '$a'
          }, onChanged: (v) { setState(() => _anio = v!); _cargar(); })),
        ],
      ),
    );
  }

  Widget _dropdown<T>({required T value, required Map<T, String> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: VaiaColors.bgSubtle,
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        border: Border.all(color: VaiaColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary),
          items: items.entries.map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _resumen(Map<String, dynamic>? r) {
    if (r == null) return const SizedBox.shrink();
    String money(dynamic v) => '\$${(double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2)}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: VaiaColors.primaryGradient,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
      ),
      child: Row(
        children: [
          _kpi('${r['viajes'] ?? 0}', 'Viajes'),
          _kpi(money(r['total']), 'Gastado'),
          _kpi('${(double.tryParse(r['km']?.toString() ?? '') ?? 0).toStringAsFixed(1)} km', 'Recorrido'),
          _kpi('${(double.tryParse(r['promedio']?.toString() ?? '') ?? 0).toStringAsFixed(1)}', 'Calificacion'),
        ],
      ),
    );
  }

  Widget _kpi(String valor, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _vacio() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        const Icon(Icons.history_rounded, size: 72, color: VaiaColors.textMuted),
        const SizedBox(height: 12),
        const Center(child: Text('Sin viajes en este periodo', style: TextStyle(color: VaiaColors.textSecondary))),
      ],
    );
  }

  Widget _card(RideModel v) {
    final cond = v.conductor;
    final monto = v.montoActual;
    final color = _statusColor(v.estatus);

    return Container(
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.border),
        boxShadow: VaiaShadows.card,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        onTap: () => Navigator.pushNamed(context, '/trip-detail', arguments: {'idServicio': v.id}),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: VaiaColors.primaryGhost,
                    backgroundImage: (cond?.fotoperfil != null && cond!.fotoperfil!.isNotEmpty) ? NetworkImage(cond.fotoperfil!) : null,
                    child: (cond?.fotoperfil == null || cond!.fotoperfil!.isEmpty)
                        ? const Icon(Icons.person_rounded, color: VaiaColors.primary, size: 22)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cond?.nombreCompleto.isNotEmpty == true ? cond!.nombreCompleto : 'Conductor',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                        Text(_fecha(v.fechaCreacion), style: const TextStyle(fontSize: 11.5, color: VaiaColors.textMuted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${monto.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: VaiaColors.textPrimary)),
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(v.estatus ?? '--', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ruta(Icons.trip_origin, VaiaColors.success, v.direccionOrigen),
              Padding(
                padding: const EdgeInsets.only(left: 7),
                child: Container(width: 2, height: 12, color: VaiaColors.border),
              ),
              _ruta(Icons.location_on_rounded, VaiaColors.danger, v.direccionDestino),
              const SizedBox(height: 10),
              Row(
                children: [
                  _chip(Icons.route_rounded, '${(v.distanciaMetros / 1000).toStringAsFixed(1)} km'),
                  if ((v.unidad ?? '').isNotEmpty) ...[const SizedBox(width: 8), _chip(Icons.directions_car_rounded, '${v.unidad} ${v.placas ?? ''}'.trim())],
                  if ((v.tipoviaje ?? '').isNotEmpty) ...[const SizedBox(width: 8), _chip(Icons.local_taxi_rounded, v.tipoviaje!)],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String? estatus) {
    final e = (estatus ?? '').toLowerCase();
    if (e.contains('finaliz') || e.contains('pagad')) return VaiaColors.success;
    if (e.contains('cancel')) return VaiaColors.danger;
    if (e.contains('camino')) return VaiaColors.primary;
    return VaiaColors.textMuted;
  }

  Widget _ruta(IconData icon, Color color, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(texto.isEmpty ? '-' : texto, style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _chip(IconData icon, String texto) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: VaiaColors.bgSubtle, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: VaiaColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(child: Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VaiaColors.textSecondary), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  String _fecha(String? iso) {
    if (iso == null || iso.isEmpty) return '--';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

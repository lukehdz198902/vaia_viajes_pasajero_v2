import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_provider.dart';
import '../../models/ride_model.dart';
import '../../config/theme.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RideProvider>().cargarHistorial();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        _hasMore &&
        !context.read<RideProvider>().loading) {
      _currentPage++;
      context.read<RideProvider>().cargarHistorial(pagina: _currentPage);
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
    });
    await context.read<RideProvider>().cargarHistorial();
  }

  Color _statusColor(String? estatus) {
    switch (estatus?.toLowerCase()) {
      case 'finalizado':
        return Colors.green;
      case 'cancelado':
        return AppTheme.danger;
      case 'en camino':
        return AppTheme.primary;
      default:
        return AppTheme.textMedium;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideProv = context.watch<RideProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Historial de Viajes'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        titleTextStyle: const TextStyle(
          color: AppTheme.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: rideProv.historial.isEmpty && rideProv.loading
          ? const Center(child: CircularProgressIndicator())
          : rideProv.historial.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 64, color: AppTheme.textLight),
                      const SizedBox(height: 16),
                      const Text(
                        'Sin viajes realizados',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tus viajes apareceran aqui',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: rideProv.historial.length + (_hasMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == rideProv.historial.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final ride = rideProv.historial[i];
                      return _buildRideCard(ride);
                    },
                  ),
                ),
    );
  }

  Widget _buildRideCard(RideModel ride) {
    final color = _statusColor(ride.estatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SizedBox.shrink(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.circle,
                                size: 10, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ride.direccionOrigen,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textDark,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: SizedBox(
                            height: 16,
                            child: Row(
                              children: [
                                Text('  |',
                                    style: TextStyle(color: AppTheme.border)),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 10, color: AppTheme.danger),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ride.direccionDestino,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        ride.costoFormateado,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ride.estatus ?? '--',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14, color: AppTheme.textLight),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(ride.fechaCreacion),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  const Spacer(),
                  if (ride.calificacionPasajero != null &&
                      ride.calificacionPasajero! > 0)
                    Row(
                      children: List.generate(
                        5,
                        (j) => Icon(
                          j < ride.calificacionPasajero!
                              ? Icons.star
                              : Icons.star_border,
                          size: 14,
                          color: j < ride.calificacionPasajero!
                              ? AppTheme.secondary
                              : AppTheme.border,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

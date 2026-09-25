import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_provider.dart';
import '../../config/theme.dart';
import 'home_screen.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> with SingleTickerProviderStateMixin {
  int _rating = 0;
  final _commentController = TextEditingController();
  final Set<String> _tags = {};
  bool _isLoading = false;
  late final AnimationController _entrada;

  static const _frases = {1: 'Malo', 2: 'Regular', 3: 'Bueno', 4: 'Muy bueno', 5: 'Excelente'};
  static const _opciones = [
    ('Conduccion segura', Icons.shield_rounded),
    ('Unidad limpia', Icons.cleaning_services_rounded),
    ('Amable', Icons.sentiment_satisfied_alt_rounded),
    ('Puntual', Icons.schedule_rounded),
    ('Buena ruta', Icons.alt_route_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _entrada.forward();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _entrada.dispose();
    super.dispose();
  }

  String _comentarioFinal() {
    final partes = <String>[];
    if (_tags.isNotEmpty) partes.add(_tags.join(', '));
    final t = _commentController.text.trim();
    if (t.isNotEmpty) partes.add(t);
    final texto = partes.join('. ');
    return texto.length > 500 ? texto.substring(0, 500) : texto;
  }

  Future<void> _calificar() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una calificacion'), backgroundColor: VaiaColors.danger),
      );
      return;
    }
    setState(() => _isLoading = true);
    final rideProv = context.read<RideProvider>();
    final ride = rideProv.currentRide;
    if (ride == null) { setState(() => _isLoading = false); return; }

    final comentario = _comentarioFinal();
    final success = await rideProv.calificarViaje(ride.id, _rating, comentarios: comentario.isEmpty ? null : comentario);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      rideProv.clearCurrentRide();
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al enviar calificacion'), backgroundColor: VaiaColors.danger),
      );
    }
  }

  void _skip() {
    context.read<RideProvider>().clearCurrentRide();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>().currentRide;
    final cond = ride?.conductor;
    final monto = ride?.montoActual ?? 0;

    return Scaffold(
      backgroundColor: VaiaColors.bgLight,
      body: SafeArea(
        child: FadeTransition(
          opacity: _entrada,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Icon(Icons.check_circle_rounded, size: 56, color: VaiaColors.success),
                const SizedBox(height: 10),
                const Text('Viaje completado',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Gracias por viajar con Vaia', style: TextStyle(fontSize: 13.5, color: VaiaColors.textSecondary)),
                const SizedBox(height: 26),

                // Tarjeta del conductor
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: VaiaColors.surface,
                    borderRadius: BorderRadius.circular(VaiaRadius.lg),
                    border: Border.all(color: VaiaColors.border),
                    boxShadow: VaiaShadows.card,
                  ),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: VaiaColors.primaryGhost,
                      backgroundImage: (cond?.fotoperfil != null && cond!.fotoperfil!.isNotEmpty) ? NetworkImage(cond.fotoperfil!) : null,
                      child: (cond?.fotoperfil == null || cond!.fotoperfil!.isEmpty)
                          ? const Icon(Icons.person_rounded, size: 40, color: VaiaColors.primary)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(cond?.nombreCompleto?.isNotEmpty == true ? cond!.nombreCompleto : 'Conductor',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                    if ((cond?.calificacion ?? 0) > 0) ...[
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.star_rounded, size: 16, color: VaiaColors.accent),
                        const SizedBox(width: 3),
                        Text(cond!.calificacion!.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _resumen(Icons.route_rounded, '${((ride?.distanciaMetros ?? 0) / 1000).toStringAsFixed(1)} km', 'Recorrido')),
                      Expanded(child: _resumen(Icons.payments_rounded, '\$${monto.toStringAsFixed(2)}', 'Total')),
                    ]),
                  ]),
                ),
                const SizedBox(height: 26),

                const Text('Como estuvo tu viaje?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final activo = i < _rating;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        scale: activo ? 1.1 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(activo ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 46, color: activo ? VaiaColors.accent : VaiaColors.borderStrong),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _rating > 0 ? _frases[_rating]! : ' ',
                    key: ValueKey(_rating),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: VaiaColors.primary),
                  ),
                ),
                const SizedBox(height: 20),

                if (_rating > 0) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _opciones.map((o) {
                      final sel = _tags.contains(o.$1);
                      return FilterChip(
                        selected: sel,
                        onSelected: (v) => setState(() => v ? _tags.add(o.$1) : _tags.remove(o.$1)),
                        avatar: Icon(o.$2, size: 16, color: sel ? Colors.white : VaiaColors.textSecondary),
                        label: Text(o.$1),
                        labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? Colors.white : VaiaColors.textPrimary),
                        backgroundColor: VaiaColors.surface,
                        selectedColor: VaiaColors.primary,
                        showCheckmark: false,
                        side: BorderSide(color: sel ? VaiaColors.primary : VaiaColors.border),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Comentarios (opcional)',
                      counterText: '',
                      filled: true,
                      fillColor: VaiaColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(VaiaRadius.md), borderSide: const BorderSide(color: VaiaColors.border)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _calificar,
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Enviar calificacion', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
                TextButton(
                  onPressed: _skip,
                  child: const Text('Omitir', style: TextStyle(color: VaiaColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resumen(IconData icon, String valor, String label) {
    return Column(children: [
      Icon(icon, size: 20, color: VaiaColors.primary),
      const SizedBox(height: 4),
      Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
      Text(label, style: const TextStyle(fontSize: 11, color: VaiaColors.textMuted)),
    ]);
  }
}

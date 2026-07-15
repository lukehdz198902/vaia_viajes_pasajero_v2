import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_provider.dart';
import '../../config/theme.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _calificar() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una calificacion'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final rideProv = context.read<RideProvider>();
    final ride = rideProv.currentRide;
    if (ride == null) {
      setState(() => _isLoading = false);
      return;
    }
    final success = await rideProv.calificarViaje(
      ride.id,
      _rating,
      comentarios: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      rideProv.clearCurrentRide();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const _HomePlaceholder()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al enviar calificacion'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  void _skip() {
    context.read<RideProvider>().clearCurrentRide();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _HomePlaceholder()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideProvider>().currentRide;
    final cond = ride?.conductor;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.bgLight,
                  backgroundImage: cond?.fotoperfil != null
                      ? NetworkImage(cond!.fotoperfil!)
                      : null,
                  child: cond?.fotoperfil == null
                      ? Icon(Icons.person, size: 48, color: AppTheme.textLight)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  cond?.nombreCompleto ?? 'Conductor',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Califica tu viaje',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          i < _rating ? Icons.star : Icons.star_border,
                          size: 40,
                          color: i < _rating
                              ? AppTheme.secondary
                              : AppTheme.border,
                        ),
                      ),
                    );
                  }),
                ),
                if (_rating > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    _rating == 1
                        ? 'Malo'
                        : _rating == 2
                            ? 'Regular'
                            : _rating == 3
                                ? 'Bueno'
                                : _rating == 4
                                    ? 'Muy bueno'
                                    : 'Excelente',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Comentarios (opcional)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _calificar,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Calificar Viaje',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'Omitir',
                    style: TextStyle(color: AppTheme.textMedium),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Regresando al inicio...')),
    );
  }
}

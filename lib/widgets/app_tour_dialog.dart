import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/storage_service.dart';

class _TourStep {
  final IconData icon;
  final String title;
  final String text;
  const _TourStep(this.icon, this.title, this.text);
}

/// Guia rapida que se muestra una sola vez despues del primer inicio de sesion.
Future<void> mostrarTourPasajero(BuildContext context) async {
  final storage = StorageService();
  if (await storage.getTourCompletado()) return;
  if (!context.mounted) return;

  final steps = <_TourStep>[
    const _TourStep(Icons.pin_drop_rounded, 'Elige tu origen y destino',
        'Toca el mapa para marcar un punto o usa el buscador. Tambien puedes agregar paradas intermedias.'),
    const _TourStep(Icons.tune_rounded, 'Configura tu viaje',
        'Antes de solicitar, elige tipo de viaje, metodo de pago y tus preferencias: musica, aire, mascotas o accesibilidad.'),
    const _TourStep(Icons.local_taxi_rounded, 'Sigue a tu conductor',
        'Cuando acepten el servicio veras la unidad en el mapa en tiempo real y podras chatear o llamar al conductor.'),
    const _TourStep(Icons.payments_rounded, 'Paga y califica',
        'Al finalizar revisa el total, califica el servicio y consulta el recorrido real desde tu historial.'),
    const _TourStep(Icons.health_and_safety_rounded, 'Configura tu contacto de emergencia',
        'En Ajustes registra un contacto de emergencia. Si activas SOS, se le enviara un correo con los datos del viaje.'),
  ];

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TourDialog(steps: steps),
  );
  await storage.setTourCompletado(true);
}

class _TourDialog extends StatefulWidget {
  final List<_TourStep> steps;
  const _TourDialog({required this.steps});

  @override
  State<_TourDialog> createState() => _TourDialogState();
}

class _TourDialogState extends State<_TourDialog> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_page];
    final last = _page == widget.steps.length - 1;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: const BoxDecoration(gradient: VaiaColors.heroGradient),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(step.icon, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 12),
                const Text('Bienvenido a Vaia',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('Paso ${_page + 1} de ${widget.steps.length}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.84), fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            height: 170,
            child: PageView.builder(
              controller: _pc,
              itemCount: widget.steps.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final s = widget.steps[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                  child: Column(
                    children: [
                      Text(s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
                      const SizedBox(height: 10),
                      Text(s.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13.5, height: 1.5, color: VaiaColors.textSecondary)),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.steps.length, (i) {
                    final sel = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: sel ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: sel ? VaiaColors.primary : VaiaColors.borderStrong,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      if (last) {
                        Navigator.pop(context);
                      } else {
                        _pc.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
                      }
                    },
                    child: Text(last ? 'Empezar a usar Vaia' : 'Siguiente'),
                  ),
                ),
                if (!last)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Omitir tour'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

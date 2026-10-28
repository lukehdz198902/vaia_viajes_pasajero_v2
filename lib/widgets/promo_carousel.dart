import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/promocion_model.dart';

/// Carrusel moderno de promociones/anuncios para el inicio del pasajero.
/// Se desliza horizontalmente, avanza solo y muestra indicadores de pagina.
/// Si la promocion no tiene imagen, usa un degradado con el titulo.
class PromoCarousel extends StatefulWidget {
  final List<PromocionModel> promociones;
  final void Function(PromocionModel promo)? onTapPromo;
  final double height;
  const PromoCarousel({super.key, required this.promociones, this.onTapPromo, this.height = 168});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  late final PageController _pc;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.9);
    _iniciarAuto();
  }

  void _iniciarAuto() {
    _timer?.cancel();
    if (widget.promociones.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pc.hasClients) return;
      final next = (_page + 1) % widget.promociones.length;
      _pc.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void didUpdateWidget(covariant PromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.promociones.length != widget.promociones.length) _iniciarAuto();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  Uint8List? _bytes(String? b64) {
    if (b64 == null || b64.trim().isEmpty) return null;
    try {
      final s = b64.contains(',') ? b64.substring(b64.indexOf(',') + 1) : b64;
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.promociones.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pc,
            itemCount: widget.promociones.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _card(widget.promociones[i]),
          ),
        ),
        if (widget.promociones.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.promociones.length, (i) {
              final sel = _page == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: sel ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: sel ? VaiaColors.primary : VaiaColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _card(PromocionModel p) {
    final bytes = _bytes(p.imgBase64);
    final gradients = <Gradient>[
      VaiaColors.primaryGradient,
      const LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFFF59E0B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      VaiaColors.heroGradient,
    ];
    final grad = gradients[p.id % gradients.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: widget.onTapPromo == null ? null : () => widget.onTapPromo!(p),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(decoration: BoxDecoration(gradient: grad)),
              if (bytes != null)
                Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
                      child: const Text('PUBLICIDAD',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (p.titulo ?? '').trim().isEmpty ? 'Anuncio' : p.titulo!,
                      style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900, height: 1.1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((p.descripcion ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.descripcion!,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Row(children: [
                      Icon(Icons.touch_app_rounded, size: 13, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('Ver mas', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

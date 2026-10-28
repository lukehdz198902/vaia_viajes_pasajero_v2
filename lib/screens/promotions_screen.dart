import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/promocion_model.dart';
import '../../providers/profile_provider.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  final _codigoCtrl = TextEditingController();
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().cargarPromociones();
    });
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _validarCodigo() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingrese un codigo promocional'), backgroundColor: AppTheme.danger));
      return;
    }
    setState(() => _isValidating = true);
    final profile = context.read<ProfileProvider>();
    final result = await profile.validarCodigoPromocional(codigo, 0);
    if (!mounted) return;
    setState(() => _isValidating = false);
    if (result != null) {
      final descuento = result['montodescuento'] ?? result['Montodescuento'] ?? 0;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Codigo valido! Descuento: \$$descuento'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Codigo invalido o expirado'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Promociones'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        titleTextStyle: const TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      body: Column(
        children: [
          Expanded(
            child: profile.loading && profile.promociones.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : profile.promociones.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.card_giftcard, size: 64, color: AppTheme.textLight),
                        const SizedBox(height: 10),
                        const Text(
                          'Sin promociones disponibles',
                          style: TextStyle(fontSize: 18, color: AppTheme.textMedium),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Vuelve pronto para nuevas ofertas',
                          style: TextStyle(fontSize: 14, color: AppTheme.textLight),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => profile.cargarPromociones(),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: profile.promociones.length,
                      itemBuilder: (ctx, i) => _buildPromoCard(profile.promociones[i]),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codigoCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ingresa tu codigo',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _validarCodigo(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isValidating ? null : _validarCodigo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                          foregroundColor: AppTheme.textDark,
                        ),
                        child: _isValidating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textDark),
                              )
                            : const Text('Validar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard(PromocionModel promo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (promo.imgBase64 != null && promo.imgBase64!.isNotEmpty)
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08)),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: _base64ToBytes(promo.imgBase64!) != null
                      ? Image.memory(
                          _base64ToBytes(promo.imgBase64!)!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 140,
                          errorBuilder: (_, _, _) => _buildPlaceholderBanner(),
                        )
                      : _buildPlaceholderBanner(),
                ),
              ),
            )
          else
            _buildPlaceholderBanner(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.titulo ?? 'Promocion',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                ),
                if (promo.descripcion != null && promo.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    promo.descripcion!,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textMedium),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.date_range, size: 14, color: AppTheme.textLight),
                    const SizedBox(width: 4),
                    Text(
                      _formatVigencia(promo.inicioVigencia, promo.finVigencia),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                    ),
                  ],
                ),
                if ((promo.url ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(promo.url!.trim());
                        if (uri == null) return;
                        try {
                          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                            await launchUrl(uri);
                          }
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Abrir enlace de la promocion'),
                    ),
                  ),
                ],
                if ((promo.codigo ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.confirmation_number_outlined, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text('Codigo: ', style: const TextStyle(fontSize: 12.5, color: AppTheme.textMedium)),
                      Expanded(
                        child: Text(promo.codigo!.trim(),
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textDark, letterSpacing: 1)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: promo.codigo!.trim()));
                        _codigoCtrl.text = promo.codigo!.trim();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Codigo ${promo.codigo!.trim()} copiado'), backgroundColor: AppTheme.primary),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        foregroundColor: AppTheme.textDark,
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Usar codigo'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBanner() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.15), AppTheme.secondary.withValues(alpha: 0.15)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: Icon(Icons.card_giftcard, size: 48, color: AppTheme.primary)),
    );
  }

  String _formatVigencia(String? inicio, String? fin) {
    try {
      final ini = inicio != null ? DateTime.parse(inicio) : null;
      final fn = fin != null ? DateTime.parse(fin) : null;
      final iniStr = ini != null ? '${ini.day}/${ini.month}/${ini.year}' : '--';
      final finStr = fn != null ? '${fn.day}/${fn.month}/${fn.year}' : '--';
      return 'Vigente: $iniStr - $finStr';
    } catch (_) {
      return 'Vigente: --';
    }
  }

  Uint8List? _base64ToBytes(String base64) {
    try {
      var data = base64.trim();
      if (data.isEmpty) return null;
      final comma = data.indexOf(',');
      if (comma >= 0) data = data.substring(comma + 1);
      data = data.replaceAll(RegExp(r'\s'), '');
      if (data.isEmpty) return null;
      return base64Decode(data);
    } catch (e) {
      return null;
    }
  }
}

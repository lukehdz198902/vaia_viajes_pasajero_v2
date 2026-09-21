import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

/// Aviso moderno para verificar el correo electronico del pasajero.
class EmailVerificationSheet extends StatefulWidget {
  const EmailVerificationSheet({super.key});

  /// Muestra la hoja y devuelve true si el correo quedo verificado.
  static Future<bool> mostrar(BuildContext context) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const EmailVerificationSheet(),
    );
    return r ?? false;
  }

  @override
  State<EmailVerificationSheet> createState() => _EmailVerificationSheetState();
}

class _EmailVerificationSheetState extends State<EmailVerificationSheet> {
  final _codigoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  bool _enviando = false;
  bool _verificando = false;
  bool _codigoEnviado = false;
  bool _editandoCorreo = false;
  String? _correoNuevo;

  @override
  void initState() {
    super.initState();
    _correoCtrl.text = context.read<AuthProvider>().user?.correo ?? '';
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? VaiaColors.danger : VaiaColors.success),
    );
  }

  Future<void> _enviarCodigo({String? correoNuevo}) async {
    final auth = context.read<AuthProvider>();
    setState(() => _enviando = true);
    final ok = await auth.enviarCodigoCorreo(correoNuevo: correoNuevo);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _codigoEnviado = ok;
    });
    _snack(ok ? 'Codigo enviado a tu correo' : 'No se pudo enviar el codigo', error: !ok);
  }

  Future<void> _verificar() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.length < 6) {
      _snack('Ingresa el codigo de 6 digitos', error: true);
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() => _verificando = true);
    final ok = _correoNuevo != null
        ? await auth.cambiarCorreo(_correoNuevo!, codigo)
        : await auth.validarCodigoCorreo(codigo);
    if (!mounted) return;
    setState(() => _verificando = false);
    if (ok) {
      _snack('Correo verificado');
      Navigator.pop(context, true);
    } else {
      _snack(auth.error ?? 'Codigo invalido', error: true);
    }
  }

  Future<void> _guardarCorreo() async {
    final nuevo = _correoCtrl.text.trim();
    if (!RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\-\.]{2,}$').hasMatch(nuevo)) {
      _snack('Correo invalido', error: true);
      return;
    }
    setState(() {
      _editandoCorreo = false;
      _correoNuevo = nuevo;
    });
    await _enviarCodigo(correoNuevo: nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final correo = context.watch<AuthProvider>().user?.correo ?? '';
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: VaiaColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _correoChip(correo),
                      const SizedBox(height: 20),
                      if (!_codigoEnviado) ...[
                        _paso(numero: '1', titulo: 'Envia el codigo', detalle: 'Te enviaremos un codigo de 6 digitos al correo indicado.'),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _enviando ? null : _enviarCodigo,
                            icon: _enviando
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send_rounded),
                            label: const Text('Enviar codigo'),
                          ),
                        ),
                      ] else ...[
                        _paso(numero: '2', titulo: 'Ingresa el codigo', detalle: 'Escribe el codigo de 6 digitos que llego a tu correo.'),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _codigoCtrl,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                          decoration: const InputDecoration(labelText: 'Codigo de verificacion', counterText: ''),
                          onSubmitted: (_) => _verificar(),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _verificando ? null : _verificar,
                            icon: _verificando
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.verified_rounded),
                            label: const Text('Verificar correo'),
                          ),
                        ),
                        TextButton(onPressed: _enviando ? null : _enviarCodigo, child: const Text('Reenviar codigo')),
                      ],
                      const Divider(height: 28),
                      if (_editandoCorreo) ...[
                        TextField(
                          controller: _correoCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Nuevo correo electronico', prefixIcon: Icon(Icons.alternate_email_rounded)),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: OutlinedButton(onPressed: () => setState(() => _editandoCorreo = false), child: const Text('Cancelar'))),
                          const SizedBox(width: 10),
                          Expanded(child: ElevatedButton(onPressed: _enviando ? null : _guardarCorreo, child: const Text('Guardar y enviar'))),
                        ]),
                      ] else
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _editandoCorreo = true),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('Cambiar correo'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mas tarde'))),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [VaiaColors.primaryDark, VaiaColors.primary]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44, height: 5,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.mark_email_unread_rounded, color: VaiaColors.primaryDark, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Verifica tu correo',
                        style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text('Protege tu cuenta y no pierdas acceso',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _correoChip(String correo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VaiaColors.primaryGhost,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VaiaColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alternate_email_rounded, size: 18, color: VaiaColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              correo.isEmpty ? 'Sin correo registrado' : correo,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paso({required String numero, required String titulo, required String detalle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26, height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: VaiaColors.primary, shape: BoxShape.circle),
          child: Text(numero, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 2),
              Text(detalle, style: const TextStyle(color: VaiaColors.textSecondary, fontSize: 12.5)),
            ],
          ),
        ),
      ],
    );
  }
}

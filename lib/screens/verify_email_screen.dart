import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../widgets/vaia_widgets.dart';

/// Verificacion del correo electronico del pasajero.
///
/// - Si [obligatorio] es false (flujo normal al ingresar) el usuario puede
///   omitir la verificacion por ahora.
/// - Permite corregir el correo: se envia un codigo al correo nuevo y al
///   validarlo se actualiza.
class VerifyEmailScreen extends StatefulWidget {
  final bool obligatorio;

  const VerifyEmailScreen({super.key, this.obligatorio = false});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  bool _enviando = false;
  bool _verificando = false;
  bool _codigoEnviado = false;
  String? _correoDestino;

  @override
  void initState() {
    super.initState();
    _correoDestino = context.read<AuthProvider>().user?.correo;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? VaiaColors.danger : null),
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
      if (ok) _correoDestino = correoNuevo ?? auth.user?.correo;
    });
    if (ok) {
      _snack('Codigo enviado a $_correoDestino');
    } else {
      _snack(auth.error ?? 'No se pudo enviar el codigo', error: true);
    }
  }

  Future<void> _verificar() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      _snack('Ingrese el codigo de 6 digitos', error: true);
      return;
    }
    final auth = context.read<AuthProvider>();
    final esCorreoNuevo = _correoDestino != null && _correoDestino != auth.user?.correo;
    setState(() => _verificando = true);
    final ok = esCorreoNuevo
        ? await auth.cambiarCorreo(_correoDestino!, code)
        : await auth.validarCodigoCorreo(code);
    if (!mounted) return;
    setState(() => _verificando = false);
    if (ok) {
      _snack('Correo verificado correctamente');
      Navigator.of(context).pop(true);
    } else {
      _snack(auth.error ?? 'Codigo incorrecto', error: true);
    }
  }

  Future<void> _corregirCorreo() async {
    final controller = TextEditingController(text: _correoDestino ?? '');
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Corregir correo'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nuevo correo electronico'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enviar codigo'),
          ),
        ],
      ),
    );
    if (nuevo == null || nuevo.isEmpty) return;
    if (!nuevo.contains('@') || !nuevo.contains('.')) {
      _snack('Correo invalido', error: true);
      return;
    }
    await _enviarCodigo(correoNuevo: nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final correo = _correoDestino ?? '';
    return Scaffold(
      appBar: AppBar(
        leading: widget.obligatorio
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(false),
              ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: VaiaColors.primaryGhost,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.mark_email_unread_rounded, size: 56, color: VaiaColors.primary),
              ),
              const SizedBox(height: 20),
              Text('Verifica tu correo', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Te enviaremos un codigo de 6 digitos a:\n$correo',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaiaColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!_codigoEnviado)
                VaiaPrimaryButton(
                  label: 'Enviar codigo',
                  icon: Icons.send_rounded,
                  loading: _enviando,
                  onPressed: _enviando ? null : () => _enviarCodigo(),
                )
              else ...[
                VaiaTextField(
                  controller: _codeController,
                  label: 'Codigo de verificacion',
                  hint: '6 digitos',
                  prefixIcon: Icons.password_rounded,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 16),
                VaiaPrimaryButton(
                  label: 'Verificar correo',
                  icon: Icons.check_rounded,
                  loading: _verificando,
                  onPressed: _verificando ? null : _verificar,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _enviando ? null : () => _enviarCodigo(correoNuevo: _correoDestino),
                  child: const Text('Reenviar codigo'),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _corregirCorreo,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Corregir correo electronico'),
              ),
              if (!widget.obligatorio) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Omitir por ahora'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

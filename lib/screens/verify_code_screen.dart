import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/vaia_widgets.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onVerified;
  final String? title;
  final String? subtitle;

  /// Valida el codigo contra el backend. Si se define, tiene prioridad
  /// sobre la verificacion local.
  final Future<bool> Function(String code)? onVerify;

  /// Reenvia el codigo. Si se define, se ejecuta al pulsar "Reenviar codigo".
  final Future<bool> Function()? onResend;

  /// Icono mostrado en la cabecera.
  final IconData? icon;

  const VerifyCodeScreen({
    super.key,
    required this.phoneNumber,
    required this.onVerified,
    this.title,
    this.subtitle,
    this.onVerify,
    this.onResend,
    this.icon,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;

  @override
  void dispose() {
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.length == 1 && index == 5) {
      _verifyCode();
    }
  }

  void _onKeyEvent(int index, String value) {
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese el codigo completo')),
      );
      return;
    }
    setState(() => _isVerifying = true);
    bool ok;
    if (widget.onVerify != null) {
      ok = await widget.onVerify!(code);
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      ok = code == '000000';
    }
    if (!mounted) return;
    setState(() => _isVerifying = false);
    if (ok) {
      widget.onVerified();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codigo incorrecto, intente de nuevo')),
      );
      for (var c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: VaiaColors.primaryGhost,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  widget.icon ?? Icons.smartphone_rounded,
                  size: 56,
                  color: VaiaColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title ?? 'Verificacion',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle ?? 'Ingrese el codigo de 6 digitos enviado a ${widget.phoneNumber}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaiaColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                  width: 48,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      counterText: '',
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty) { _onDigitChanged(i, v); }
                      else { _onKeyEvent(i, v); }
                    },
                  ),
                )),
              ),
              const SizedBox(height: 28),
              VaiaPrimaryButton(
                label: 'Verificar',
                icon: Icons.check_rounded,
                loading: _isVerifying,
                onPressed: _isVerifying ? null : _verifyCode,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  if (widget.onResend != null) {
                    final ok = await widget.onResend!();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Codigo reenviado' : 'No se pudo reenviar el codigo')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Codigo reenviado')),
                    );
                  }
                },
                child: const Text('Reenviar codigo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
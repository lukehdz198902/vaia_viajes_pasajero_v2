import 'package:flutter/material.dart';
import '../../config/theme.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onVerified;
  final String? title;
  final String? subtitle;

  const VerifyCodeScreen({
    super.key,
    required this.phoneNumber,
    required this.onVerified,
    this.title,
    this.subtitle,
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
        const SnackBar(content: Text('Ingrese el codigo completo'), backgroundColor: AppTheme.danger),
      );
      return;
    }
    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (code == '000000') {
      widget.onVerified();
    } else {
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codigo incorrecto, intente de nuevo'), backgroundColor: AppTheme.danger),
      );
      for (var c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Verificar Codigo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(Icons.smartphone, size: 72, color: AppTheme.primary),
              const SizedBox(height: 24),
              Text(
                widget.title ?? 'Verificacion',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle ?? 'Ingrese el codigo de 6 digitos enviado a ${widget.phoneNumber}',
                style: const TextStyle(fontSize: 14, color: AppTheme.textMedium),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => SizedBox(
                  width: 48,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty) { _onDigitChanged(i, v); }
                      else { _onKeyEvent(i, v); }
                    },
                  ),
                )),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  child: _isVerifying
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verificar'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Codigo reenviado'), backgroundColor: AppTheme.primary),
                  );
                },
                child: const Text('Reenviar Codigo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

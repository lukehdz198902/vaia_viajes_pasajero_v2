import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'verify_code_screen.dart';
import 'reset_password_screen.dart';

class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({super.key});

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneCtrl.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerifyCodeScreen(
          phoneNumber: phone,
          title: 'Recuperar Contrasena',
          subtitle: 'Ingrese el codigo enviado a su WhatsApp',
          onVerified: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(phoneNumber: phone),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Recuperar Contrasena')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(Icons.lock_open, size: 72, color: AppTheme.primary),
                const SizedBox(height: 24),
                const Text(
                  'Recuperar contrasena',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingrese su numero de telefono a 10 digitos para recibir un codigo de verificacion',
                  style: TextStyle(fontSize: 14, color: AppTheme.textMedium),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    hintText: '5512345678',
                    prefixIcon: Icon(Icons.phone_outlined),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingrese su telefono';
                    if (v.trim().length != 10) return 'Deben ser 10 digitos';
                    if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Solo numeros';
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _next(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _next,
                    child: const Text('Enviar Codigo'),
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

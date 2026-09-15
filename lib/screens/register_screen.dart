import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../services/logger.dart';
import '../../widgets/vaia_widgets.dart';
import 'verify_code_screen.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _appaternoController = TextEditingController();
  final _apmaternoController = TextEditingController();
  final _emailController = TextEditingController();
  final _codigoPaisController = TextEditingController(text: '+52');
  final _telefonoController = TextEditingController();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _appaternoController.dispose();
    _apmaternoController.dispose();
    _emailController.dispose();
    _codigoPaisController.dispose();
    _telefonoController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final data = {
      'idCompania': 1,
      'googlekey': '',
      'nombre': _nombreController.text.trim(),
      'appaterno': _appaternoController.text.trim(),
      'apmaterno': _apmaternoController.text.trim(),
      'correo': _emailController.text.trim(),
      'codigopaistel': _codigoPaisController.text.trim(),
      'telefono': _telefonoController.text.trim(),
      'account': _accountController.text.trim(),
      'pass': _passwordController.text,
    };
    Logger.i('RegisterScreen', 'register() data: $data');
    final success = await auth.register(data);
    if (!mounted) return;
    setState(() => _isLoading = false);
    Logger.i('RegisterScreen', 'register() result: success=$success error=${auth.error}');
    if (success) {
      if (!mounted) return;
      final phone = '${_codigoPaisController.text.trim()} ${_telefonoController.text.trim()}';
      final nav = Navigator.of(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyCodeScreen(
            phoneNumber: phone,
            title: 'Verificar Registro',
            subtitle: 'Ingrese el codigo enviado a su WhatsApp',
            onVerified: () {
              auth.verifyRegistrationCode('000000').then((loggedIn) {
                if (loggedIn) {
                  nav.pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const HomeScreen(),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                    ),
                    (route) => false,
                  );
                }
              });
            },
          ),
        ),
      );
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: VaiaColors.danger),
      );
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Crear cuenta', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 6),
                Text(
                  'Unete a Vaia Viajes y empieza a moverte',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaiaColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _sectionLabel(context, 'Informacion personal', Icons.person_outline_rounded),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: VaiaTextField(
                        controller: _nombreController,
                        label: 'Nombre',
                        prefixIcon: Icons.badge_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: VaiaTextField(
                        controller: _appaternoController,
                        label: 'Ap. Paterno',
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _apmaternoController,
                  label: 'Ap. Materno (opcional)',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _emailController,
                  label: 'Correo electronico',
                  hint: 'tu@correo.com',
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (!v.contains('@') || !v.contains('.')) return 'Correo invalido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: VaiaTextField(
                        controller: _codigoPaisController,
                        label: 'Codigo',
                        prefixIcon: Icons.flag_outlined,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: VaiaTextField(
                        controller: _telefonoController,
                        label: 'Telefono',
                        prefixIcon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (v.trim().length != 10) return '10 digitos';
                          if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Solo numeros';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionLabel(context, 'Datos de la cuenta', Icons.lock_outline_rounded),
                const SizedBox(height: 10),
                VaiaTextField(
                  controller: _accountController,
                  label: 'Usuario',
                  hint: 'Tu nombre de usuario',
                  prefixIcon: Icons.alternate_email_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _passwordController,
                  label: 'Contrasena',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length < 6) return 'Minimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                VaiaTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar contrasena',
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v != _passwordController.text) return 'No coinciden';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                VaiaPrimaryButton(
                  label: 'Crear cuenta',
                  icon: Icons.arrow_forward_rounded,
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _register,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ya tienes cuenta?', style: Theme.of(context).textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Inicia sesion'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: VaiaColors.primaryGhost,
            borderRadius: BorderRadius.circular(VaiaRadius.sm),
          ),
          child: Icon(icon, size: 16, color: VaiaColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.4),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../services/google_auth_service.dart';
import '../../widgets/vaia_widgets.dart';
import '../../widgets/login_background.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'recover_password_screen.dart';
import 'verify_email_screen.dart';

const String _linkDescargaPasajero =
    'https://play.google.com/store/apps/details?id=prozoft.com.vaia&hl=es_MX';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _irAHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (route) => false,
    );
  }

  Future<void> _loginConGoogle() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    try {
      final idToken = await GoogleAuthService.obtenerIdToken();
      if (!mounted) return;
      if (idToken == null) {
        setState(() => _isLoading = false);
        return;
      }
      final ok = await auth.loginConGoogle(idToken);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (ok) {
        _irAHome();
        if (!auth.correoConfirmado) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'No se pudo iniciar sesion con Google'), backgroundColor: VaiaColors.danger),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: VaiaColors.danger),
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _accountController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
        (route) => false,
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
      body: Stack(
        children: [
          Positioned.fill(child: LoginBackground(accent: VaiaColors.primary, accent2: VaiaColors.accent)),
          SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Center(child: VaiaLogo(size: 64, showText: true)),
                  const SizedBox(height: 18),
                  Text(
                    'Bienvenido de vuelta',
                    style: Theme.of(context).textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Inicia sesion para continuar tu viaje',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VaiaColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        VaiaTextField(
                          controller: _accountController,
                          label: 'Correo o telefono',
                          hint: 'Correo verificado o telefono verificado',
                          prefixIcon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Ingrese su cuenta' : null,
                        ),
                        const SizedBox(height: 14),
                        VaiaTextField(
                          controller: _passwordController,
                          label: 'Contrasena',
                          hint: 'Ingrese su contrasena',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Ingrese su contrasena' : null,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RecoverPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text('Olvide mi contrasena'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        VaiaPrimaryButton(
                          label: 'Iniciar sesion',
                          icon: Icons.arrow_forward_rounded,
                          loading: _isLoading,
                          onPressed: _isLoading ? null : _login,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'o continua con',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  VaiaOutlineButton(
                    label: 'Continuar con Google',
                    icon: Icons.g_mobiledata_rounded,
                    fullWidth: true,
                    onPressed: _isLoading ? null : _loginConGoogle,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: _compartirApp,
                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                      label: const Text('Invita a un amigo'),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No tienes cuenta?', style: Theme.of(context).textTheme.bodyMedium),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: const Text('Registrate'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
        ),
      ],
    ),
  );
  }

  Future<void> _compartirApp() async {
    final msg = Uri.encodeComponent(
        'Viaja seguro y comodo con Vaia. Descarga la app gratis: $_linkDescargaPasajero');
    final uri = Uri.parse('https://wa.me/?text=$msg');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await Clipboard.setData(const ClipboardData(text: _linkDescargaPasajero));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace de descarga copiado'), backgroundColor: VaiaColors.success),
    );
  }
}
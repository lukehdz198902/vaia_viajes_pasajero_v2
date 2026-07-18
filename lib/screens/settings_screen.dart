import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../config/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _passActualCtrl = TextEditingController();
  final _passNuevoCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _showPasswordSection = false;
  bool _isLoadingPassword = false;

  final _codigoPaisCtrl = TextEditingController(text: '+52');
  final _telefonoCtrl = TextEditingController();
  final _codigoVerifCtrl = TextEditingController();
  bool _showPhoneSection = false;
  bool _codigoEnviado = false;
  bool _isLoadingPhone = false;

  @override
  void dispose() {
    _passActualCtrl.dispose();
    _passNuevoCtrl.dispose();
    _passConfirmCtrl.dispose();
    _codigoPaisCtrl.dispose();
    _telefonoCtrl.dispose();
    _codigoVerifCtrl.dispose();
    super.dispose();
  }

  Future<void> _cambiarPassword() async {
    if (_passNuevoCtrl.text != _passConfirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contrasenas no coinciden'), backgroundColor: AppTheme.danger),
      );
      return;
    }
    setState(() => _isLoadingPassword = true);
    final profile = context.read<ProfileProvider>();
    final success = await profile.cambiarPassword(_passActualCtrl.text, _passNuevoCtrl.text);
    if (!mounted) return;
    setState(() => _isLoadingPassword = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Contrasena cambiada correctamente' : 'Error al cambiar contrasena'),
        backgroundColor: success ? Colors.green : AppTheme.danger,
      ),
    );
    if (success) {
      _passActualCtrl.clear();
      _passNuevoCtrl.clear();
      _passConfirmCtrl.clear();
      setState(() => _showPasswordSection = false);
    }
  }

  Future<void> _enviarCodigo() async {
    setState(() => _codigoEnviado = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Codigo de verificacion enviado'), backgroundColor: AppTheme.primary),
    );
  }

  Future<void> _cambiarTelefono() async {
    setState(() => _isLoadingPhone = true);
    final profile = context.read<ProfileProvider>();
    final success = await profile.cambiarTelefono(_codigoPaisCtrl.text, _telefonoCtrl.text, _codigoVerifCtrl.text);
    if (!mounted) return;
    setState(() => _isLoadingPhone = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Telefono actualizado correctamente' : 'Error al cambiar telefono'),
        backgroundColor: success ? Colors.green : AppTheme.danger,
      ),
    );
    if (success) {
      setState(() {
        _showPhoneSection = false;
        _codigoEnviado = false;
        _telefonoCtrl.clear();
        _codigoVerifCtrl.clear();
      });
    }
  }

  Future<void> _cerrarSesion() async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Sesion'),
        content: const Text('Esta seguro de que desea cerrar sesion?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Cerrar Sesion'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const _LogoutPlaceholder()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final isDark = themeProv.isDarkMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Apariencia'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SwitchListTile(
                  title: const Text('Modo Nocturno', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(isDark ? 'Oscuro' : 'Claro', style: const TextStyle(color: AppTheme.textMedium)),
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppTheme.primary),
                  value: isDark,
                  onChanged: (v) => themeProv.setDarkMode(v),
                  activeTrackColor: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Seguridad'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showPasswordSection = !_showPasswordSection),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cambiar Contrasena',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                            ),
                          ),
                          Icon(_showPasswordSection ? Icons.expand_less : Icons.expand_more, color: AppTheme.textMedium),
                        ],
                      ),
                    ),
                    if (_showPasswordSection) ...[
                      const SizedBox(height: 16),
                      _buildField('Contrasena actual', _passActualCtrl, obscure: true),
                      const SizedBox(height: 12),
                      _buildField('Nueva contrasena', _passNuevoCtrl, obscure: true),
                      const SizedBox(height: 12),
                      _buildField('Confirmar contrasena', _passConfirmCtrl, obscure: true),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoadingPassword ? null : _cambiarPassword,
                          child: _isLoadingPassword
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Cambiar Contrasena'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Informacion de contacto'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showPhoneSection = !_showPhoneSection),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cambiar Telefono',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                            ),
                          ),
                          Icon(_showPhoneSection ? Icons.expand_less : Icons.expand_more, color: AppTheme.textMedium),
                        ],
                      ),
                    ),
                    if (_showPhoneSection) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(width: 80, child: _buildField('', _codigoPaisCtrl)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildField('Telefono nuevo', _telefonoCtrl, keyboardType: TextInputType.phone)),
                        ],
                      ),
                      if (!_codigoEnviado) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _enviarCodigo,
                            child: const Text('Enviar Codigo de Verificacion'),
                          ),
                        ),
                      ],
                      if (_codigoEnviado) ...[
                        const SizedBox(height: 12),
                        _buildField('Codigo de verificacion', _codigoVerifCtrl),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoadingPhone ? null : _cambiarTelefono,
                            child: _isLoadingPhone
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Confirmar Cambio'),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Cuenta'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cerrarSesion,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar Sesion'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Acerca de'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Version', style: TextStyle(fontSize: 14, color: AppTheme.textDark)),
                    Text('1.0.0', style: TextStyle(fontSize: 14, color: AppTheme.textMedium)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {bool obscure = false, TextInputType keyboardType = TextInputType.text, String? hint}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        hintText: hint,
      ),
    );
  }
}

class _LogoutPlaceholder extends StatelessWidget {
  const _LogoutPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Sesion cerrada')),
    );
  }
}

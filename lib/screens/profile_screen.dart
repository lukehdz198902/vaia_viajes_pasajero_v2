import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../config/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nombreCtrl = TextEditingController();
  final _appaternoCtrl = TextEditingController();
  final _apmaternoCtrl = TextEditingController();
  final _fechaNacCtrl = TextEditingController();
  final _generoCtrl = TextEditingController();
  bool _isLoading = false;

  final _passActualCtrl = TextEditingController();
  final _passNuevoCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _showPasswordSection = false;

  final _codigoPaisCtrl = TextEditingController(text: '+52');
  final _telefonoCtrl = TextEditingController();
  final _codigoVerifCtrl = TextEditingController();
  bool _showPhoneSection = false;
  bool _codigoEnviado = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nombreCtrl.text = user.nombre;
      _appaternoCtrl.text = user.appaterno;
      _apmaternoCtrl.text = user.apmaterno;
      _fechaNacCtrl.text = user.fechanacimiento ?? '';
      _generoCtrl.text = user.genero ?? '';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _appaternoCtrl.dispose();
    _apmaternoCtrl.dispose();
    _fechaNacCtrl.dispose();
    _generoCtrl.dispose();
    _passActualCtrl.dispose();
    _passNuevoCtrl.dispose();
    _passConfirmCtrl.dispose();
    _codigoPaisCtrl.dispose();
    _telefonoCtrl.dispose();
    _codigoVerifCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    setState(() => _isLoading = true);
    final profile = context.read<ProfileProvider>();
    final success = await profile.actualizarPerfil({
      'nombre': _nombreCtrl.text.trim(),
      'appaterno': _appaternoCtrl.text.trim(),
      'apmaterno': _apmaternoCtrl.text.trim(),
      'fechanacimiento': _fechaNacCtrl.text.trim(),
      'genero': _generoCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Perfil actualizado correctamente'
            : 'Error al actualizar perfil'),
        backgroundColor: success ? Colors.green : AppTheme.danger,
      ),
    );
  }

  Future<void> _cambiarPassword() async {
    if (_passNuevoCtrl.text != _passConfirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contrasenas no coinciden'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final profile = context.read<ProfileProvider>();
    final success = await profile.cambiarPassword(
      _passActualCtrl.text,
      _passNuevoCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            success ? 'Contrasena cambiada' : 'Error al cambiar contrasena'),
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
      const SnackBar(
        content: Text('Codigo de verificacion enviado'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Future<void> _cambiarTelefono() async {
    setState(() => _isLoading = true);
    final profile = context.read<ProfileProvider>();
    final success = await profile.cambiarTelefono(
      _codigoPaisCtrl.text,
      _telefonoCtrl.text,
      _codigoVerifCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Telefono actualizado'
            : 'Error al cambiar telefono'),
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        titleTextStyle: const TextStyle(
          color: AppTheme.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppTheme.bgLight,
                      backgroundImage: user?.fotoperfil != null
                          ? NetworkImage(user!.fotoperfil!)
                          : null,
                      child: user?.fotoperfil == null
                          ? Icon(Icons.person,
                              size: 44, color: AppTheme.textLight)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.nombreCompleto ?? 'Usuario',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.correo ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMedium,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user != null
                          ? '${user.codigopaistel} ${user.telefono}'
                          : '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informacion personal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildField('Nombre', _nombreCtrl),
                    const SizedBox(height: 12),
                    _buildField('Apellido paterno', _appaternoCtrl),
                    const SizedBox(height: 12),
                    _buildField('Apellido materno', _apmaternoCtrl),
                    const SizedBox(height: 12),
                    _buildField('Fecha de nacimiento', _fechaNacCtrl,
                        hint: 'YYYY-MM-DD'),
                    const SizedBox(height: 12),
                    _buildField('Genero', _generoCtrl,
                        hint: 'Masculino / Femenino / Otro'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _guardarCambios,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Guardar Cambios'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => setState(
                          () => _showPasswordSection = !_showPasswordSection),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cambiar Contrasena',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          Icon(
                            _showPasswordSection
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: AppTheme.textMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_showPasswordSection) ...[
                      const SizedBox(height: 16),
                      _buildField('Contrasena actual', _passActualCtrl,
                          obscure: true),
                      const SizedBox(height: 12),
                      _buildField('Nueva contrasena', _passNuevoCtrl,
                          obscure: true),
                      const SizedBox(height: 12),
                      _buildField('Confirmar contrasena', _passConfirmCtrl,
                          obscure: true),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _cambiarPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondary,
                            foregroundColor: AppTheme.textDark,
                          ),
                          child: const Text('Cambiar Contrasena'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => setState(
                          () => _showPhoneSection = !_showPhoneSection),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Cambiar Telefono',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                          Icon(
                            _showPhoneSection
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: AppTheme.textMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_showPhoneSection) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: _buildField('', _codigoPaisCtrl),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildField('Telefono nuevo', _telefonoCtrl,
                                keyboardType: TextInputType.phone),
                          ),
                        ],
                      ),
                      if (!_codigoEnviado) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _enviarCodigo,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondary,
                              foregroundColor: AppTheme.textDark,
                            ),
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
                            onPressed: _isLoading ? null : _cambiarTelefono,
                            child: const Text('Confirmar Cambio'),
                          ),
                        ),
                      ],
                    ],
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

  Widget _buildField(String label, TextEditingController controller,
      {bool obscure = false,
      TextInputType keyboardType = TextInputType.text,
      String? hint}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }
}

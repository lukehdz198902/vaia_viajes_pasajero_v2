import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../config/theme.dart';
import '../../widgets/email_verification_sheet.dart';

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

  final _picker = ImagePicker();
  String? _fotoBase64;
  DateTime? _fechaNac;
  String _genero = '';

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
      if ((user.fechanacimiento ?? '').isNotEmpty) {
        _fechaNac = DateTime.tryParse(user.fechanacimiento!);
      }
      _genero = user.genero ?? '';
    }
  }

  /// Sube o cambia la foto de perfil (camara o galeria).
  Future<void> _cambiarFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Tomar foto'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Elegir de galeria'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (origen == null) return;
    final foto = await _picker.pickImage(source: origen, imageQuality: 55, maxWidth: 800);
    if (foto == null) return;
    final bytes = await foto.readAsBytes();
    if (!mounted) return;
    setState(() => _fotoBase64 = base64Encode(bytes));
  }

  Future<void> _seleccionarFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaNac ?? DateTime(ahora.year - 25, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime(ahora.year - 10, ahora.month, ahora.day),
      helpText: 'Selecciona tu fecha de nacimiento',
    );
    if (elegida == null) return;
    setState(() => _fechaNac = elegida);
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
      if (_fechaNac != null) 'fechanacimiento': DateFormat('yyyy-MM-dd').format(_fechaNac!),
      if (_genero.isNotEmpty) 'genero': _genero,
      if (_fotoBase64 != null) 'fotoperfil': _fotoBase64,
    });
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      await context.read<AuthProvider>().refreshPerfil();
    }
    if (!mounted) return;
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
    final profile = context.read<ProfileProvider>();
    final ok = await profile.enviarCodigoVerificacion();
    if (!mounted) return;
    setState(() => _codigoEnviado = ok);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Codigo de verificacion enviado' : 'Error al enviar codigo'),
        backgroundColor: ok ? AppTheme.primary : AppTheme.danger,
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
  Widget _buildDateField() {
    return InkWell(
      onTap: _seleccionarFecha,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha de nacimiento',
          prefixIcon: Icon(Icons.calendar_month_outlined),
          border: OutlineInputBorder(),
        ),
        child: Text(
          _fechaNac != null ? DateFormat('dd/MM/yyyy').format(_fechaNac!) : 'Selecciona una fecha',
          style: TextStyle(color: _fechaNac != null ? AppTheme.textDark : AppTheme.textLight),
        ),
      ),
    );
  }

  Widget _buildGeneroField() {
    return DropdownButtonFormField<String>(
      initialValue: _genero.isEmpty ? null : _genero,
      decoration: const InputDecoration(
        labelText: 'Genero',
        prefixIcon: Icon(Icons.wc_outlined),
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'M', child: Text('Masculino')),
        DropdownMenuItem(value: 'F', child: Text('Femenino')),
        DropdownMenuItem(value: 'O', child: Text('Otro')),
      ],
      onChanged: (v) => setState(() => _genero = v ?? ''),
    );
  }

  Widget _badgeVerificacion(IconData icon, String label, bool verificado, {VoidCallback? onVerificar}) {
    final color = verificado ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);
    return InkWell(
      onTap: verificado ? null : onVerificar,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(verificado ? Icons.verified_rounded : Icons.error_outline_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            verificado ? '$label verificado' : 'Verificar $label',
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
          if (!verificado) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 14, color: color),
          ],
        ]),
      ),
    );
  }

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
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppTheme.bgLight,
                          backgroundImage: _fotoBase64 != null
                              ? MemoryImage(base64Decode(_fotoBase64!))
                              : (user?.fotoperfil != null && user!.fotoperfil!.isNotEmpty
                                  ? NetworkImage(user.fotoperfil!)
                                  : null),
                          child: (_fotoBase64 == null && (user?.fotoperfil == null || user!.fotoperfil!.isEmpty))
                              ? const Icon(Icons.person, size: 44, color: AppTheme.textLight)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: AppTheme.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _cambiarFoto,
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _badgeVerificacion(Icons.alternate_email_rounded, 'Correo', user?.correoConfirmado == true,
                            onVerificar: () => EmailVerificationSheet.mostrar(context)),
                        _badgeVerificacion(Icons.phone_android_rounded, 'Telefono', user?.telefonoConfirmado == true,
                            onVerificar: () => setState(() => _showPhoneSection = true)),
                      ],
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
                    _buildDateField(),
                    const SizedBox(height: 12),
                    _buildGeneroField(),
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

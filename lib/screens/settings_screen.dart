import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/locale_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/storage_service.dart';
import 'login_screen.dart';
import 'pin_screens.dart';

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
  bool _biometria = false;
  bool _pinHabilitado = false;

  // Contacto de emergencia
  final _emNombreCtrl = TextEditingController();
  final _emTelCtrl = TextEditingController();
  final _emCorreo1Ctrl = TextEditingController();
  final _emCorreo2Ctrl = TextEditingController();
  bool _guardandoEmergencia = false;

  // Dispositivos
  List<Map<String, dynamic>> _sesiones = [];

  @override
  void initState() {
    super.initState();
    StorageService().getBiometriaHabilitada().then((v) {
      if (mounted) setState(() => _biometria = v);
    });
    StorageService().getPinHabilitado().then((v) {
      if (mounted) setState(() => _pinHabilitado = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarEmergenciaYSesiones());
  }

  void _toast(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppTheme.success : AppTheme.danger,
    ));
  }

  Future<void> _cargarEmergenciaYSesiones() async {
    final auth = context.read<AuthProvider>();
    final api = context.read<ApiService>();
    try {
      final c = await api.obtenerContactoEmergencia(auth.userId);
      if (c.success && c.firstOrNull() is Map) {
        final m = Map<String, dynamic>.from(c.firstOrNull() as Map);
        if (mounted) {
          setState(() {
            _emNombreCtrl.text = m['nombrecompleto']?.toString() ?? '';
            _emTelCtrl.text = m['telefono']?.toString() ?? '';
            _emCorreo1Ctrl.text = m['correo1']?.toString() ?? '';
            _emCorreo2Ctrl.text = m['correo2']?.toString() ?? '';
          });
        }
      }
    } catch (_) {}
    try {
      final token = await StorageService().getSessionToken();
      final s = await api.listarSesiones(auth.userId, tokenActual: token);
      if (s.success && s.list != null && mounted) {
        setState(() => _sesiones = s.list!.map((e) => Map<String, dynamic>.from(e as Map)).toList());
      }
    } catch (_) {}
  }

  Future<void> _guardarEmergencia() async {
    if (_emNombreCtrl.text.trim().isEmpty) { _toast('Ingresa el nombre del contacto', ok: false); return; }
    final tel = _emTelCtrl.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(tel)) { _toast('El telefono debe tener 10 digitos', ok: false); return; }
    if (_emCorreo1Ctrl.text.trim().isEmpty) { _toast('Ingresa el correo electronico principal', ok: false); return; }
    final auth = context.read<AuthProvider>();
    final api = context.read<ApiService>();
    setState(() => _guardandoEmergencia = true);
    final res = await api.guardarContactoEmergencia({
      'idPasajero': auth.userId,
      'nombrecompleto': _emNombreCtrl.text.trim(),
      'telefono': tel,
      'correo1': _emCorreo1Ctrl.text.trim(),
      'correo2': _emCorreo2Ctrl.text.trim().isEmpty ? null : _emCorreo2Ctrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _guardandoEmergencia = false);
    _toast(res.success ? 'Contacto de emergencia guardado' : 'No se pudo guardar', ok: res.success);
  }

  Future<void> _cerrarDispositivo(Map<String, dynamic> s) async {
    final auth = context.read<AuthProvider>();
    final api = context.read<ApiService>();
    final id = int.tryParse(s['id']?.toString() ?? '') ?? 0;
    if (id <= 0) return;
    final res = await api.cerrarSesionDispositivo(id, auth.userId);
    if (res.success && mounted) {
      _toast('Sesion cerrada en el dispositivo');
      _cargarEmergenciaYSesiones();
    }
  }

  /// Activa, cambia o desactiva el PIN de seguridad.
  Future<void> _configurarPin(bool v) async {
    final storage = StorageService();
    if (v) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (ok == true && mounted) {
        setState(() => _pinHabilitado = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN de seguridad activado'), backgroundColor: AppTheme.success),
        );
      }
    } else {
      await storage.removePin();
      if (mounted) setState(() => _pinHabilitado = false);
    }
  }

  /// Activa o desactiva la seguridad biometrica.
  Future<void> _cambiarBiometria(bool v) async {
    final storage = StorageService();
    if (v) {
      final disponible = await BiometricService.disponible();
      if (!disponible) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tu dispositivo no tiene biometria configurada'), backgroundColor: AppTheme.danger),
          );
        }
        return;
      }
      final ok = await BiometricService.autenticar(motivo: 'Activa la seguridad biometrica de Vaia');
      if (!ok) return;
      await storage.setBiometriaHabilitada(true);
    } else {
      await storage.setBiometriaHabilitada(false);
    }
    if (mounted) setState(() => _biometria = v);
  }

  @override
  void dispose() {
    _passActualCtrl.dispose();
    _passNuevoCtrl.dispose();
    _passConfirmCtrl.dispose();
    _codigoPaisCtrl.dispose();
    _telefonoCtrl.dispose();
    _codigoVerifCtrl.dispose();
    _emNombreCtrl.dispose();
    _emTelCtrl.dispose();
    _emCorreo1Ctrl.dispose();
    _emCorreo2Ctrl.dispose();
    super.dispose();
  }

  String _fechaAcceso(dynamic iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      return 'Ultimo acceso: ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
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
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final idioma = context.watch<LocaleProvider>();
    final isDark = themeProv.isDarkMode;

    return Scaffold(
      appBar: AppBar(title: Text(S.t(context, 'Configuracion', 'Settings'))),
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
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.language_rounded, color: AppTheme.primary),
                title: const Text('Idioma / Language', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(idioma.lang == 'en' ? 'English' : 'Espanol', style: const TextStyle(color: AppTheme.textMedium)),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'es', label: Text('ES')),
                    ButtonSegment(value: 'en', label: Text('EN')),
                  ],
                  selected: {idioma.lang},
                  onSelectionChanged: (s) => idioma.setLang(s.first),
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
            _sectionHeader('Seguridad'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Seguridad biometrica', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_biometria ? 'Activada' : 'Desactivada', style: const TextStyle(color: AppTheme.textMedium)),
                    secondary: const Icon(Icons.fingerprint_rounded),
                    value: _biometria,
                    onChanged: _cambiarBiometria,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('PIN de seguridad', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_pinHabilitado ? 'Activado (4 digitos)' : 'Desactivado', style: const TextStyle(color: AppTheme.textMedium)),
                    secondary: const Icon(Icons.pin_rounded),
                    value: _pinHabilitado,
                    onChanged: _configurarPin,
                  ),
                  if (_pinHabilitado)
                    ListTile(
                      leading: const SizedBox(width: 40, child: Icon(Icons.password_rounded, color: AppTheme.primary)),
                      title: const Text('Cambiar PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                      onTap: () => _configurarPin(true),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Permisos y privacidad'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/permisos'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Ver permisos y politicas'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Contacto de emergencia'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildField('Nombre completo', _emNombreCtrl),
                    const SizedBox(height: 12),
                    _buildField('Telefono (10 digitos, con codigo de pais)', _emTelCtrl, keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _buildField('Correo electronico 1', _emCorreo1Ctrl, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildField('Correo electronico 2 (opcional)', _emCorreo2Ctrl, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _guardandoEmergencia ? null : _guardarEmergencia,
                        icon: _guardandoEmergencia
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: const Text('Guardar contacto'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Dispositivos conectados'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _sesiones.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No hay dispositivos registrados', style: TextStyle(color: AppTheme.textMedium)),
                      )
                    : Column(
                        children: _sesiones.map((s) {
                          final esActual = s['esactual'] == true || s['esactual']?.toString() == '1';
                          return ListTile(
                            leading: Icon(Icons.smartphone_rounded, color: esActual ? AppTheme.primary : AppTheme.textMedium),
                            title: Text((s['dispositivo'] ?? 'Dispositivo').toString(),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${s['sistemaoperativo'] ?? ''}\n${_fechaAcceso(s['ultimoacceso'])}',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMedium)),
                            isThreeLine: true,
                            trailing: esActual
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                                    child: const Text('Este dispositivo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.logout_rounded, color: AppTheme.danger, size: 20),
                                    onPressed: () => _cerrarDispositivo(s),
                                  ),
                          );
                        }).toList(),
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

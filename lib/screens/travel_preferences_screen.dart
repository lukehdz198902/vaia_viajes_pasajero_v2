import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/preferencias_viaje_model.dart';
import '../providers/profile_provider.dart';

/// Preferencias que el conductor debe conocer antes y durante el servicio.
class TravelPreferencesScreen extends StatefulWidget {
  final bool onboarding;
  const TravelPreferencesScreen({super.key, this.onboarding = false});

  @override
  State<TravelPreferencesScreen> createState() => _TravelPreferencesScreenState();
}

class _TravelPreferencesScreenState extends State<TravelPreferencesScreen> {
  late PreferenciasViaje _p;
  late final TextEditingController _alergiasCtrl;
  late final TextEditingController _discapacidadCtrl;
  late final TextEditingController _notasCtrl;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final actual = context.read<ProfileProvider>().preferencias;
    _p = PreferenciasViaje(
      configurado: actual.configurado,
      musica: actual.musica,
      aireAcondicionado: actual.aireAcondicionado,
      ventanasAbajo: actual.ventanasAbajo,
      alergias: actual.alergias,
      discapacidad: actual.discapacidad,
      viajaConMascotas: actual.viajaConMascotas,
      discapacidadAuditiva: actual.discapacidadAuditiva,
      discapacidadVisual: actual.discapacidadVisual,
      notas: actual.notas,
    );
    _alergiasCtrl = TextEditingController(text: _p.alergias);
    _discapacidadCtrl = TextEditingController(text: _p.discapacidad);
    _notasCtrl = TextEditingController(text: _p.notas);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().cargarPreferenciasViaje();
    });
  }

  @override
  void dispose() {
    _alergiasCtrl.dispose();
    _discapacidadCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    _p.alergias = _alergiasCtrl.text;
    _p.discapacidad = _discapacidadCtrl.text;
    _p.notas = _notasCtrl.text;
    final ok = await context.read<ProfileProvider>().guardarPreferenciasViaje(_p);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron guardar las preferencias'), backgroundColor: VaiaColors.danger),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VaiaColors.bgLight,
      appBar: AppBar(
        title: Text(widget.onboarding ? 'Configura tu viaje' : 'Preferencias de viaje'),
        leading: widget.onboarding ? const SizedBox.shrink() : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: VaiaColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tu viaje, a tu manera',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      SizedBox(height: 3),
                      Text('El conductor vera estas preferencias al aceptar tu servicio.',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _seccion('Ambiente del viaje'),
          _opcionMusica(),
          _switchCard(
            icon: Icons.ac_unit_rounded,
            title: 'Aire acondicionado',
            subtitle: 'Mantener el aire encendido durante el viaje',
            value: _p.aireAcondicionado,
            onChanged: (v) => setState(() => _p.aireAcondicionado = v),
          ),
          _switchCard(
            icon: Icons.window_rounded,
            title: 'Ventanas abajo',
            subtitle: 'Prefiero viajar con las ventanas abajo',
            value: _p.ventanasAbajo,
            onChanged: (v) => setState(() => _p.ventanasAbajo = v),
          ),
          const SizedBox(height: 12),
          _seccion('Necesidades y accesibilidad'),
          _switchCard(
            icon: Icons.pets_rounded,
            title: 'Viajo con mascotas',
            subtitle: 'Avisa al conductor si llevas una mascota',
            value: _p.viajaConMascotas,
            onChanged: (v) => setState(() => _p.viajaConMascotas = v),
          ),
          _switchCard(
            icon: Icons.hearing_disabled_rounded,
            title: 'Discapacidad auditiva',
            subtitle: 'El conductor recibira esta indicacion',
            value: _p.discapacidadAuditiva,
            onChanged: (v) => setState(() => _p.discapacidadAuditiva = v),
          ),
          _switchCard(
            icon: Icons.visibility_off_rounded,
            title: 'Discapacidad visual',
            subtitle: 'El conductor recibira esta indicacion',
            value: _p.discapacidadVisual,
            onChanged: (v) => setState(() => _p.discapacidadVisual = v),
          ),
          const SizedBox(height: 12),
          _seccion('Datos que el conductor debe saber'),
          _campo(_alergiasCtrl, 'Alergias', 'Ej. polen, mariscos, penicilina...', Icons.warning_amber_rounded),
          _campo(_discapacidadCtrl, 'Discapacidad o apoyo requerido', 'Ej. silla de ruedas, baston, acompanante...', Icons.accessible_rounded),
          _campo(_notasCtrl, 'Otras indicaciones', 'Ej. ayudo con el equipaje, necesito llegar rapido...', Icons.edit_note_rounded),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(widget.onboarding ? 'Guardar y continuar' : 'Guardar preferencias'),
            ),
          ),
          if (widget.onboarding) ...[
            const SizedBox(height: 8),
            const Text(
              'Solo tendras que configurarlas una vez. Podras cambiarlas despues en Ajustes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: VaiaColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _seccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8, top: 4),
      child: Text(titulo,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: VaiaColors.primary, letterSpacing: 0.3)),
    );
  }

  Widget _opcionMusica() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VaiaColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded, color: VaiaColors.primary, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Musica', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text('Elige el ambiente para tu viaje', style: TextStyle(fontSize: 11.5, color: VaiaColors.textSecondary)),
              ],
            ),
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Sin musica')),
              ButtonSegment(value: true, label: Text('Con musica')),
            ],
            selected: {_p.musica},
            onSelectionChanged: (v) => setState(() => _p.musica = v.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: value ? VaiaColors.primary.withValues(alpha: 0.45) : VaiaColors.border),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        dense: true,
        activeThumbColor: VaiaColors.primary,
        secondary: Icon(icon, color: value ? VaiaColors.primary : VaiaColors.textMuted, size: 21),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: VaiaColors.textSecondary)),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        maxLength: 300,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          counterText: '',
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}

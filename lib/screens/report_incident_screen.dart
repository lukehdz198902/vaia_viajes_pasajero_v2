import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../config/theme.dart';

class ReportIncidentScreen extends StatefulWidget {
  final int? idServicio;

  const ReportIncidentScreen({super.key, this.idServicio});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _descCtrl = TextEditingController();
  List<String> _tiposIncidente = [];
  String? _selectedTipo;
  bool _isLoadingTipos = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _cargarTiposIncidente();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTiposIncidente() async {
    setState(() => _isLoadingTipos = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.pasajeroEndpoint}/ObtenerTiposIncidente');
      final response = await http.get(uri).timeout(ApiConfig.timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        List<dynamic> list = decoded is List ? decoded : (decoded['data'] ?? []);
        final tipos = list.map<String>((e) {
          if (e is String) return e;
          if (e is Map) return (e['nombre'] ?? e['Nombre'] ?? e.toString()) as String;
          return e.toString();
        }).toList();
        setState(() {
          _tiposIncidente = tipos;
          _isLoadingTipos = false;
        });
      } else {
        setState(() {
          _tiposIncidente = [
            'Conductor grosero',
            'Vehiculo en mal estado',
            'Ruta incorrecta',
            'Cobro excesivo',
            'Otro',
          ];
          _isLoadingTipos = false;
        });
      }
    } catch (_) {
      setState(() {
        _tiposIncidente = ['Conductor grosero', 'Vehiculo en mal estado', 'Ruta incorrecta', 'Cobro excesivo', 'Otro'];
        _isLoadingTipos = false;
      });
    }
  }

  Future<void> _reportar() async {
    if (_selectedTipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un tipo de incidente'), backgroundColor: AppTheme.danger),
      );
      return;
    }
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Describa el incidente'), backgroundColor: AppTheme.danger));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.pasajeroEndpoint}/ReportarIncidente');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'tipoIncidente': _selectedTipo,
              'descripcion': desc,
              if (widget.idServicio != null) 'idServicio': widget.idServicio,
            }),
          )
          .timeout(ApiConfig.timeout);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incidente reportado correctamente'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al reportar incidente'), backgroundColor: AppTheme.danger));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error de conexion'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Reportar Incidente'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        titleTextStyle: const TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipo de incidente',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingTipos)
                      const Center(
                        child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTipo,
                        decoration: const InputDecoration(
                          hintText: 'Seleccione un tipo',
                          prefixIcon: Icon(Icons.warning_amber_outlined),
                        ),
                        items: _tiposIncidente.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _selectedTipo = v),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Descripcion',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Describa el incidente con detalle...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.idServicio != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppTheme.textMedium),
                      const SizedBox(width: 8),
                      Text(
                        'Servicio #${widget.idServicio}',
                        style: const TextStyle(fontSize: 14, color: AppTheme.textMedium),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _reportar,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSubmitting ? 'Enviando...' : 'Reportar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

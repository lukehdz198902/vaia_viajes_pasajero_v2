import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/places_service.dart';

class PlaceSearchScreen extends StatefulWidget {
  final bool isOrigin;

  /// Ubicacion de referencia para priorizar los lugares mas cercanos.
  final double? lat;
  final double? lng;

  const PlaceSearchScreen({super.key, this.isOrigin = false, this.lat, this.lng});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _searchController = TextEditingController();
  List<PlacePrediction> _predictions = [];
  bool _loading = false;
  bool _hasSearched = false;
  String _error = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String input) {
    _debounce?.cancel();
    if (input.trim().isEmpty) {
      setState(() { _predictions = []; _hasSearched = false; _error = ''; });
      return;
    }
    // Espera a que el usuario deje de escribir antes de consultar a Google.
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(input));
  }

  Future<void> _search(String input) async {
    if (input.trim().isEmpty) return;
    setState(() { _loading = true; _error = ''; });
    final results = await PlacesService.autocomplete(input, lat: widget.lat, lng: widget.lng);
    if (!mounted) return;
    setState(() {
      _predictions = results;
      _loading = false;
      _hasSearched = true;
      _error = PlacesService.ultimoError;
    });
  }

  Future<void> _selectPlace(PlacePrediction pred) async {
    setState(() => _loading = true);
    final detail = await PlacesService.getPlaceDetail(pred.placeId);
    if (!mounted) return;
    if (detail == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo obtener la ubicacion${PlacesService.ultimoError.isNotEmpty ? ': ${PlacesService.ultimoError}' : ''}'),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }
    Navigator.of(context).pop({
      'name': detail.name.isNotEmpty ? detail.name : pred.description,
      'address': detail.address ?? detail.name,
      'lat': detail.location.latitude,
      'lng': detail.location.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(widget.isOrigin ? 'Buscar origen' : 'Buscar destino'),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.isOrigin ? 'Donde te recogemos?' : 'A donde vamos?',
                filled: true,
                fillColor: AppTheme.bgLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() {});
                _onChanged(v);
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _predictions.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _predictions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final pred = _predictions[i];
                          return ListTile(
                            leading: Icon(
                              widget.isOrigin ? Icons.trip_origin : Icons.location_on,
                              color: widget.isOrigin ? AppTheme.primary : AppTheme.danger,
                            ),
                            title: Text(pred.description, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                            subtitle: (pred.secondary != null && pred.secondary != pred.description)
                                ? Text(pred.secondary!, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)
                                : null,
                            onTap: () => _selectPlace(pred),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 48, color: AppTheme.textLight),
            const SizedBox(height: 12),
            const Text('Escribe para buscar un lugar', style: TextStyle(color: AppTheme.textMedium)),
          ],
        ),
      );
    }
    if (_error.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppTheme.danger),
            const SizedBox(height: 12),
            const Text('No se pudo buscar en Google', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMedium, fontSize: 12.5)),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppTheme.textLight),
          const SizedBox(height: 12),
          const Text('Sin resultados cercanos', style: TextStyle(color: AppTheme.textMedium)),
          const SizedBox(height: 4),
          const Text('Intenta con otro nombre o direccion', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Buscador compacto en hoja inferior. Devuelve el lugar elegido o
/// {'useMap': true} cuando el usuario prefiere marcar el punto en el mapa.
Future<Map<String, dynamic>?> showPlaceSearchSheet(
  BuildContext context, {
  required String titulo,
  required IconData icono,
  bool permitirMapa = true,
  double? lat,
  double? lng,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.82,
      child: _PlaceSearchSheet(
        titulo: titulo,
        icono: icono,
        permitirMapa: permitirMapa,
        lat: lat,
        lng: lng,
      ),
    ),
  );
}

class _PlaceSearchSheet extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final bool permitirMapa;
  final double? lat;
  final double? lng;
  const _PlaceSearchSheet({
    required this.titulo,
    required this.icono,
    required this.permitirMapa,
    this.lat,
    this.lng,
  });

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _ctrl = TextEditingController();
  List<PlacePrediction> _predictions = [];
  bool _loading = false;
  bool _hasSearched = false;
  String _error = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String input) {
    _debounce?.cancel();
    if (input.trim().isEmpty) {
      setState(() { _predictions = []; _hasSearched = false; _error = ''; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(input));
  }

  Future<void> _search(String input) async {
    setState(() { _loading = true; _error = ''; });
    final results = await PlacesService.autocomplete(input, lat: widget.lat, lng: widget.lng);
    if (!mounted) return;
    setState(() {
      _predictions = results;
      _loading = false;
      _hasSearched = true;
      _error = PlacesService.ultimoError;
    });
  }

  Future<void> _select(PlacePrediction pred) async {
    setState(() => _loading = true);
    final detail = await PlacesService.getPlaceDetail(pred.placeId);
    if (!mounted) return;
    if (detail == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo obtener la ubicacion${PlacesService.ultimoError.isNotEmpty ? ': ${PlacesService.ultimoError}' : ''}'),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }
    Navigator.pop(context, {
      'name': detail.name.isNotEmpty ? detail.name : pred.description,
      'address': detail.address ?? detail.name,
      'lat': detail.location.latitude,
      'lng': detail.location.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(99))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(widget.icono, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const Text('Busca una direccion o elige el punto en el mapa',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textMedium)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (v) { setState(() {}); _onChanged(v); },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Escribe una direccion o lugar...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () { _ctrl.clear(); _onChanged(''); },
                        )
                      : null,
                ),
              ),
            ),
            if (widget.permitirMapa)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, {'useMap': true}),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text('Elegir directamente en el mapa'),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _predictions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              !_hasSearched
                                  ? 'Escribe para buscar o elige el punto en el mapa.'
                                  : (_error.isNotEmpty ? 'No se pudo buscar: $_error' : 'Sin resultados. Prueba con otra direccion.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.textMedium, fontSize: 13),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
                          itemCount: _predictions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = _predictions[i];
                            return ListTile(
                              leading: Icon(widget.icono, color: AppTheme.primary, size: 21),
                              title: Text(p.description, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                              subtitle: p.secondary != null && p.secondary != p.description
                                  ? Text(p.secondary!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5))
                                  : null,
                              onTap: () => _select(p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
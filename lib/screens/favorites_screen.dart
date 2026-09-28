import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../models/favorito_model.dart';
import '../../config/theme.dart';
import '../../config/favorito_categorias.dart';
import 'place_search_screen.dart';

/// Abre la hoja para agregar un favorito, opcionalmente prellenada con un lugar
/// (por ejemplo el destino de un viaje recien terminado). Devuelve true si se
/// guardo.
Future<bool> mostrarAgregarFavorito(
  BuildContext context, {
  String? nombre,
  String? direccion,
  String? lat,
  String? lng,
  String? categoria,
}) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AgregarFavoritoSheet(
      nombreInicial: nombre,
      direccionInicial: direccion,
      latInicial: lat,
      lngInicial: lng,
      categoriaInicial: categoria,
    ),
  );
  return res == true;
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().cargarFavoritos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final favoritos = profile.favoritos;

    return Scaffold(
      backgroundColor: VaiaColors.bgLight,
      appBar: AppBar(title: const Text('Favoritos')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: VaiaColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Agregar'),
        onPressed: () async {
          final ok = await mostrarAgregarFavorito(context);
          if (ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Favorito agregado'), backgroundColor: VaiaColors.success),
            );
          }
        },
      ),
      body: profile.loading && favoritos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : favoritos.isEmpty
              ? _vacio()
              : RefreshIndicator(
                  color: VaiaColors.primary,
                  onRefresh: () => profile.cargarFavoritos(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      _mapa(favoritos),
                      const SizedBox(height: 16),
                      ..._grupos(favoritos),
                    ],
                  ),
                ),
    );
  }

  Widget _vacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_outline_rounded, size: 72, color: VaiaColors.textMuted),
            const SizedBox(height: 16),
            const Text('Sin favoritos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Agrega lugares frecuentes (Casa, Trabajo, etc.) para acceder rapidamente',
                style: TextStyle(fontSize: 13.5, color: VaiaColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await mostrarAgregarFavorito(context);
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Favorito agregado'), backgroundColor: VaiaColors.success),
                  );
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar mi primer favorito'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapa(List<FavoritoModel> favoritos) {
    final markers = <Marker>{};
    LatLng? centro;
    for (final f in favoritos) {
      final lat = double.tryParse(f.lat);
      final lng = double.tryParse(f.lng);
      if (lat == null || lng == null) continue;
      centro ??= LatLng(lat, lng);
      final cat = categoriaDe(f.categoria ?? f.nombre);
      markers.add(Marker(
        markerId: MarkerId('fav_${f.id}'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hue(cat.color)),
        infoWindow: InfoWindow(title: f.nombre, snippet: f.direccion ?? ''),
      ));
    }
    if (centro == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(VaiaRadius.lg),
      child: SizedBox(
        height: 190,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: centro, zoom: 12),
          markers: markers,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
        ),
      ),
    );
  }

  double _hue(Color c) {
    if (c == VaiaColors.primary) return BitmapDescriptor.hueCyan;
    if (c.value == const Color(0xFF3B82F6).value) return BitmapDescriptor.hueAzure;
    if (c.value == const Color(0xFFF59E0B).value) return BitmapDescriptor.hueOrange;
    if (c.value == const Color(0xFF8B5CF6).value) return BitmapDescriptor.hueViolet;
    if (c.value == const Color(0xFFEC4899).value) return BitmapDescriptor.hueRose;
    if (c.value == const Color(0xFF10B981).value) return BitmapDescriptor.hueGreen;
    return BitmapDescriptor.hueRed;
  }

  List<Widget> _grupos(List<FavoritoModel> favoritos) {
    // Agrupa por categoria conservando un orden estable.
    final orden = <String, List<FavoritoModel>>{};
    for (final f in favoritos) {
      final cat = categoriaDe(f.categoria ?? f.nombre).nombre;
      orden.putIfAbsent(cat, () => []).add(f);
    }
    final widgets = <Widget>[];
    for (final entry in orden.entries) {
      final cat = categoriaDe(entry.key);
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Row(
          children: [
            Icon(cat.icono, size: 18, color: cat.color),
            const SizedBox(width: 8),
            Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
            const SizedBox(width: 8),
            Text('(${entry.value.length})', style: const TextStyle(fontSize: 12.5, color: VaiaColors.textMuted)),
          ],
        ),
      ));
      widgets.addAll(entry.value.map((f) => _tarjeta(f, cat)));
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Widget _tarjeta(FavoritoModel f, CategoriaFavorito cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        border: Border.all(color: VaiaColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(cat.icono, color: cat.color),
        ),
        title: Text(f.nombre, style: const TextStyle(fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
        subtitle: (f.direccion ?? '').isNotEmpty
            ? Text(f.direccion!, style: const TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: VaiaColors.textMuted),
          onPressed: () => _eliminar(f),
        ),
        onTap: () => Navigator.of(context).pop({
          'nombre': f.nombre,
          'direccion': f.direccion,
          'lat': f.lat,
          'lng': f.lng,
        }),
      ),
    );
  }

  Future<void> _eliminar(FavoritoModel fav) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
        title: const Text('Eliminar favorito'),
        content: Text('Eliminar "${fav.nombre}" de tus favoritos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: VaiaColors.danger))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ProfileProvider>().eliminarFavorito(fav.id);
    }
  }
}

/// Hoja para agregar/editar un favorito con busqueda de lugar, mapa, nombre y
/// categoria. Se prellena con un lugar cuando se abre desde un viaje.
class _AgregarFavoritoSheet extends StatefulWidget {
  final String? nombreInicial;
  final String? direccionInicial;
  final String? latInicial;
  final String? lngInicial;
  final String? categoriaInicial;
  const _AgregarFavoritoSheet({this.nombreInicial, this.direccionInicial, this.latInicial, this.lngInicial, this.categoriaInicial});

  @override
  State<_AgregarFavoritoSheet> createState() => _AgregarFavoritoSheetState();
}

class _AgregarFavoritoSheetState extends State<_AgregarFavoritoSheet> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _dirCtrl;
  String? _categoria = 'Casa';
  LatLng? _pos;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreInicial ?? '');
    _dirCtrl = TextEditingController(text: widget.direccionInicial ?? '');
    final lat = double.tryParse(widget.latInicial ?? '');
    final lng = double.tryParse(widget.lngInicial ?? '');
    if (lat != null && lng != null) _pos = LatLng(lat, lng);
    if (widget.categoriaInicial != null) _categoria = widget.categoriaInicial;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final res = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen(isOrigin: false)),
    );
    if (res == null) return;
    setState(() {
      _dirCtrl.text = res['address']?.toString() ?? '';
      final lat = res['lat'];
      final lng = res['lng'];
      if (lat is num && lng is num) _pos = LatLng(lat.toDouble(), lng.toDouble());
    });
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponle un nombre al lugar')));
      return;
    }
    if (_pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Busca y selecciona la ubicacion en el mapa')));
      return;
    }
    setState(() => _guardando = true);
    final ok = await context.read<ProfileProvider>().agregarFavorito({
      'nombre': _nombreCtrl.text.trim(),
      'dir': _dirCtrl.text.trim(),
      'lat': _pos!.latitude.toString(),
      'lng': _pos!.longitude.toString(),
      'categoria': _categoria,
    });
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo guardar el favorito'), backgroundColor: VaiaColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: VaiaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: VaiaColors.border, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 16),
            const Text('Agregar favorito', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Busca el lugar, ponle nombre y elige una categoria', style: TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary)),
            const SizedBox(height: 16),

            // Mapa de previsualizacion / busqueda
            InkWell(
              onTap: _buscar,
              borderRadius: BorderRadius.circular(VaiaRadius.lg),
              child: Container(
                height: 170,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(VaiaRadius.lg),
                  border: Border.all(color: VaiaColors.border),
                  color: VaiaColors.bgSubtle,
                ),
                child: _pos == null
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_location_alt_rounded, size: 36, color: VaiaColors.primary),
                            SizedBox(height: 8),
                            Text('Toca para buscar y ubicar el lugar', style: TextStyle(fontSize: 12.5, color: VaiaColors.textSecondary)),
                          ],
                        ),
                      )
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(target: _pos!, zoom: 16),
                        markers: {
                          Marker(markerId: const MarkerId('fav'), position: _pos!, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
                        },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        scrollGesturesEnabled: false,
                        zoomGesturesEnabled: false,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: _buscar, icon: const Icon(Icons.search_rounded, size: 18), label: const Text('Buscar lugar')),
            ),

            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Casa, Trabajo, Novia'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dirCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Direccion', hintText: 'Direccion del lugar'),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Categoria', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categoriasFavorito.map((c) {
                final sel = _categoria == c.nombre;
                return GestureDetector(
                  onTap: () => setState(() => _categoria = c.nombre),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? c.color : c.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: c.color.withValues(alpha: sel ? 1 : 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(c.icono, size: 16, color: sel ? Colors.white : c.color),
                        const SizedBox(width: 6),
                        Text(c.nombre, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : c.color)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: const Text('Guardar favorito'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

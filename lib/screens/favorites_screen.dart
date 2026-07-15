import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../models/favorito_model.dart';
import '../../config/theme.dart';

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

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Favorito'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Casa, Trabajo',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Direccion',
                    hintText: 'Direccion del lugar',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Latitud',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Longitud',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Ingresa un nombre')),
                );
                return;
              }
              if (latCtrl.text.trim().isEmpty ||
                  lngCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Ingresa latitud y longitud')),
                );
                return;
              }
              final profile = ctx.read<ProfileProvider>();
              final success = await profile.agregarFavorito({
                'favoritonombre': nameCtrl.text.trim(),
                'direccionfavorito': addrCtrl.text.trim(),
                'lat': latCtrl.text.trim(),
                'lng': lngCtrl.text.trim(),
              });
              if (ctx.mounted) {
                Navigator.of(ctx).pop(success);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favorito agregado'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteFavorito(FavoritoModel fav) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar favorito'),
        content: Text('Eliminar "${fav.nombre}" de tus favoritos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ProfileProvider>().eliminarFavorito(fav.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Favoritos'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        titleTextStyle: const TextStyle(
          color: AppTheme.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: profile.loading
          ? const Center(child: CircularProgressIndicator())
          : profile.favoritos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_outline,
                          size: 64, color: AppTheme.textLight),
                      const SizedBox(height: 16),
                      const Text(
                        'Sin favoritos',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Agrega lugares frecuentes para acceder rapidamente',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => profile.cargarFavoritos(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: profile.favoritos.length,
                    itemBuilder: (ctx, i) {
                      final fav = profile.favoritos[i];
                      return Dismissible(
                        key: ValueKey(fav.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _deleteFavorito(fav);
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.danger,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.star,
                                  color: AppTheme.primary),
                            ),
                            title: Text(
                              fav.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                            subtitle: fav.direccion != null &&
                                    fav.direccion!.isNotEmpty
                                ? Text(
                                    fav.direccion!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMedium,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppTheme.textLight),
                              onPressed: () => _deleteFavorito(fav),
                            ),
                            onTap: () {
                              Navigator.of(context).pop({
                                'nombre': fav.nombre,
                                'direccion': fav.direccion,
                                'lat': fav.lat,
                                'lng': fav.lng,
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

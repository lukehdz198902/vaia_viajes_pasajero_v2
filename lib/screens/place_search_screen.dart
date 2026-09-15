import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/places_service.dart';

class PlaceSearchScreen extends StatefulWidget {
  final bool isOrigin;
  const PlaceSearchScreen({super.key, this.isOrigin = false});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _searchController = TextEditingController();
  List<PlacePrediction> _predictions = [];
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String input) async {
    if (input.trim().isEmpty) {
      setState(() { _predictions = []; _hasSearched = false; });
      return;
    }
    setState(() => _loading = true);
    final results = await PlacesService.autocomplete(input);
    if (!mounted) return;
    setState(() {
      _predictions = results;
      _loading = false;
      _hasSearched = true;
    });
  }

  Future<void> _selectPlace(PlacePrediction pred) async {
    setState(() => _loading = true);
    final detail = await PlacesService.getPlaceDetail(pred.placeId);
    if (!mounted) return;
    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al obtener ubicacion'), backgroundColor: Colors.red),
      );
      setState(() => _loading = false);
      return;
    }
    Navigator.of(context).pop({
      'name': detail.name,
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
            padding: const EdgeInsets.all(16),
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
                          _search('');
                        },
                      )
                    : null,
              ),
              onChanged: _search,
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _predictions.isEmpty
                    ? _hasSearched
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 48, color: AppTheme.textLight),
                                const SizedBox(height: 12),
                                Text('Sin resultados', style: TextStyle(color: AppTheme.textMedium)),
                              ],
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search, size: 48, color: AppTheme.textLight),
                                const SizedBox(height: 12),
                                Text('Escribe para buscar un lugar', style: TextStyle(color: AppTheme.textMedium)),
                              ],
                            ),
                          )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _predictions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final pred = _predictions[i];
                          return ListTile(
                            leading: Icon(
                              widget.isOrigin ? Icons.circle : Icons.location_on,
                              color: widget.isOrigin ? AppTheme.primary : AppTheme.danger,
                            ),
                            title: Text(pred.description, style: const TextStyle(fontSize: 14)),
                            onTap: () => _selectPlace(pred),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

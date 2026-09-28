import 'package:flutter/material.dart';

/// Categoria de un lugar favorito con su icono representativo.
class CategoriaFavorito {
  final String nombre;
  final IconData icono;
  final Color color;
  const CategoriaFavorito(this.nombre, this.icono, this.color);
}

/// Categorias sugeridas para clasificar lugares favoritos.
const List<CategoriaFavorito> categoriasFavorito = [
  CategoriaFavorito('Casa', Icons.home_rounded, Color(0xFF14B8A6)),
  CategoriaFavorito('Trabajo', Icons.work_rounded, Color(0xFF3B82F6)),
  CategoriaFavorito('Por visitar', Icons.explore_rounded, Color(0xFFF59E0B)),
  CategoriaFavorito('Universidad', Icons.school_rounded, Color(0xFF8B5CF6)),
  CategoriaFavorito('Gimnasio', Icons.fitness_center_rounded, Color(0xFFEC4899)),
  CategoriaFavorito('Familia', Icons.family_restroom_rounded, Color(0xFF10B981)),
  CategoriaFavorito('Otro', Icons.place_rounded, Color(0xFF64748B)),
];

CategoriaFavorito categoriaDe(String? nombre) {
  if (nombre == null) return categoriasFavorito.last;
  return categoriasFavorito.firstWhere(
    (c) => c.nombre.toLowerCase() == nombre.toLowerCase(),
    orElse: () => categoriasFavorito.last,
  );
}

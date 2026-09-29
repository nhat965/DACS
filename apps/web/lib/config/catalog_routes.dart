import 'package:flutter/material.dart';

@immutable
class CatalogDestination {
  const CatalogDestination({
    required this.label,
    required this.route,
    required this.icon,
    this.backendCategories = const <String>[],
  });

  final String label;
  final String route;
  final IconData icon;
  final List<String> backendCategories;
}

class CatalogRoutes {
  const CatalogRoutes._();

  static const destinations = <CatalogDestination>[
    CatalogDestination(
      label: 'Son môi',
      route: '/category/lip',
      icon: Icons.colorize_outlined,
      backendCategories: ['lip_care'],
    ),
    CatalogDestination(
      label: 'Skincare',
      route: '/category/skincare',
      icon: Icons.spa_outlined,
      backendCategories: [
        'cleanser',
        'toner',
        'serum',
        'moisturizer',
        'sunscreen',
        'exfoliant',
        'mask',
        'eye_care',
      ],
    ),
    CatalogDestination(
      label: 'Makeup',
      route: '/category/makeup',
      icon: Icons.brush_outlined,
      backendCategories: ['makeup'],
    ),
    CatalogDestination(
      label: 'Nước hoa',
      route: '/category/fragrance',
      icon: Icons.water_drop_outlined,
      backendCategories: ['fragrance'],
    ),
    CatalogDestination(
      label: 'Bodycare',
      route: '/category/bodycare',
      icon: Icons.self_improvement_outlined,
      backendCategories: ['body_care'],
    ),
    CatalogDestination(
      label: 'Hàng mới',
      route: '/new-arrivals',
      icon: Icons.new_releases_outlined,
    ),
    CatalogDestination(
      label: 'Quà tặng',
      route: '/gifts',
      icon: Icons.card_giftcard_outlined,
    ),
    CatalogDestination(
      label: 'Blog',
      route: '/blog',
      icon: Icons.menu_book_outlined,
    ),
  ];

  static const subcategories = <CatalogDestination>[
    CatalogDestination(
      label: 'Sữa rửa mặt',
      route: '/category/cleanser',
      icon: Icons.bubble_chart_outlined,
      backendCategories: ['cleanser'],
    ),
    CatalogDestination(
      label: 'Toner',
      route: '/category/toner',
      icon: Icons.water_outlined,
      backendCategories: ['toner'],
    ),
    CatalogDestination(
      label: 'Serum',
      route: '/category/serum',
      icon: Icons.science_outlined,
      backendCategories: ['serum'],
    ),
    CatalogDestination(
      label: 'Dưỡng ẩm',
      route: '/category/moisturizer',
      icon: Icons.opacity_outlined,
      backendCategories: ['moisturizer'],
    ),
    CatalogDestination(
      label: 'Chống nắng',
      route: '/category/sunscreen',
      icon: Icons.wb_sunny_outlined,
      backendCategories: ['sunscreen'],
    ),
    CatalogDestination(
      label: 'Mặt nạ',
      route: '/category/mask',
      icon: Icons.face_retouching_natural_outlined,
      backendCategories: ['mask'],
    ),
  ];

  static CatalogDestination? fromSlug(String slug) {
    final normalized = slug.trim().toLowerCase();
    for (final item in [...destinations, ...subcategories]) {
      if (item.route.endsWith('/$normalized')) return item;
    }
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

const Color _teal  = Color(0xFF0D9488);
const Color _slate = Color(0xFF64748B);

// activeIndex: 0=Home  1=Categories  2=Cart  3=Wishlist  4=Profile
Widget buildBottomNav(BuildContext context, int activeIndex) {
  final items = [
    {'icon': Icons.home_outlined,          'active': Icons.home_rounded,          'label': 'Home'},
    {'icon': Icons.grid_view_outlined,     'active': Icons.grid_view_rounded,     'label': 'Categories'},
    {'icon': Icons.shopping_cart_outlined, 'active': Icons.shopping_cart_rounded, 'label': 'Cart'},
    {'icon': Icons.favorite_outline,       'active': Icons.favorite_rounded,      'label': 'Wishlist'},
    {'icon': Icons.person_outline_rounded, 'active': Icons.person_rounded,        'label': 'Profile'},
  ];

  final routes = ['', '/categories', '/cart', '/wishlist', '/profile'];

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 16, offset: const Offset(0, -4),
      )],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final isActive = i == activeIndex;
            return GestureDetector(
              onTap: () {
                if (isActive) return;
                if (i == 0) {
                  Navigator.popUntil(context, (r) => r.isFirst);
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context, routes[i], (r) => r.isFirst);
                }
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (i == 2)
                  Consumer<CartProvider>(
                    builder: (_, cart, _) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          isActive ? items[i]['active'] as IconData
                                   : items[i]['icon']   as IconData,
                          size: 24, color: isActive ? _teal : _slate),
                        if (cart.itemCount > 0)
                          Positioned(
                            right: -5, top: -5,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: Colors.redAccent, shape: BoxShape.circle),
                              child: Text(
                                cart.itemCount > 9 ? '9+' : '${cart.itemCount}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 8,
                                    fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Icon(
                    isActive ? items[i]['active'] as IconData
                             : items[i]['icon']   as IconData,
                    size: 24, color: isActive ? _teal : _slate),
                const SizedBox(height: 3),
                Text(items[i]['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? _teal : _slate,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    )),
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    width: 4, height: 4,
                    decoration: const BoxDecoration(
                        color: _teal, shape: BoxShape.circle),
                  ),
              ]),
            );
          }),
        ),
      ),
    ),
  );
}

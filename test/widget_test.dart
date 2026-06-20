// Smoke tests for the two areas that broke tonight:
//   1. PaymentScreen — must always render exactly one "PAY" action and a
//      COD toggle, with no upfront phone-number form (the regression we
//      removed) and no Cashfree-specific picker UI in front of the button.
//   2. HomepageProvider — must start in a loading state with no sections,
//      since the loading-state widget swap (skeleton vs loaded) was the
//      root cause of the fresh-install carousel scroll bug.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:savaan/models/cart_item_model.dart';
import 'package:savaan/presentation/payment_screen.dart';
import 'package:savaan/providers/cart_provider.dart';
import 'package:savaan/providers/order_provider.dart';
import 'package:savaan/providers/homepage_provider.dart';

Widget _wrapWithProviders(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => CartProvider()),
      ChangeNotifierProvider(create: (_) => OrderProvider()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('PaymentScreen', () {
    final cartItems = [
      CartItemModel(id: 'c1', userId: 'u1', productId: 'p1', quantity: 1),
    ];

    testWidgets('renders a single PAY button and a COD toggle, no phone form',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(PaymentScreen(
        cartItems: cartItems,
        subtotal: 500,
        discount: 0,
        shipping: 50,
        total: 550,
        selectedAddressId: 'addr-1',
      )));
      await tester.pumpAndSettle();

      // Exactly one pay action — no method-picker screen in front of it.
      expect(find.textContaining('PAY'), findsOneWidget);
      // Cash on Delivery toggle must exist as the only alternative.
      expect(find.text('Cash on Delivery'), findsOneWidget);
      // The regression we removed: an upfront mobile number requirement.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('switching to COD changes the action button label',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(PaymentScreen(
        cartItems: cartItems,
        subtotal: 500,
        discount: 0,
        shipping: 50,
        total: 550,
        selectedAddressId: 'addr-1',
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cash on Delivery'));
      await tester.pumpAndSettle();

      expect(find.textContaining('PLACE ORDER'), findsOneWidget);
    });
  });

  group('HomepageProvider', () {
    test('starts in a loading state before any fetch completes', () {
      final hp = HomepageProvider();
      expect(hp.isLoading, isTrue);
      expect(hp.hasLoaded, isFalse);
      expect(hp.sections, isEmpty);
    });
  });
}

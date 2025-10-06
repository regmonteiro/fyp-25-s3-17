import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import 'otc_medication_list_page.dart';
import '../financial/payment_confirmation_page.dart';
import '../models/user_profile.dart';
import 'controller/cart_controller.dart';
import 'controller/cart_scope.dart'; // optional helper

class MedicationShopPage extends StatelessWidget {
  const MedicationShopPage({Key? key}) : super(key: key);

  static const List<Map<String, dynamic>> _marketplaceProducts = [
    {
      'id': 'market_001',
      'name': 'Daily Vitamins',
      'price': 19.90,
      'description': 'Boost immunity and energy.',
      'imageUrl': 'https://placehold.co/100x100/A855F7/ffffff?text=Vitamins',
    },
    {
      'id': 'market_002',
      'name': 'Joint Support',
      'price': 35.50,
      'description': 'Natural supplement for mobility.',
      'imageUrl': 'https://placehold.co/100x100/FACC15/000000?text=Joint+Care',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Well-being Essentials'),
        backgroundColor: Colors.lightGreen.shade700,
        elevation: 0,
        actions: [
          Consumer<CartController>(
            builder: (context, cart, _) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => _openCartSheet(context),
                ),
                if (cart.count > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${cart.count}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),

            const Text(
              'Order Medication',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              context,
              title: 'Prescribed Treatment',
              subtitle: 'For medicated drugs (consultation required for first purchase).',
              icon: FontAwesomeIcons.pills,
              color: Colors.red.shade50,
              iconColor: Colors.red.shade700,
              onTap: () {
                // push your prescription request page here if needed
              },
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              context,
              title: 'OTC Medication',
              subtitle: 'Purchase over-the-counter essentials directly.',
              icon: FontAwesomeIcons.handHoldingMedical,
              color: Colors.green.shade50,
              iconColor: Colors.green.shade700,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EnsureCartProvider( // safe even if provided globally
                      child: OTCMedicationListPage(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            const Text(
              'Discover Health & Wellness',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            ),
            const SizedBox(height: 12),

            Consumer<CartController>(
              builder: (context, cart, _) => Column(
                children: _marketplaceProducts.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MarketplaceTile(
                      product: p,
                      onAdd: () {
                        cart.add(p);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${p['name']} added to cart!'), duration: const Duration(milliseconds: 800)),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCartSheet(BuildContext parentContext) {
    final cart = parentContext.read<CartController>();      // shared instance
    final profile = parentContext.read<UserProfile?>();     // may be null
    final navigator = Navigator.of(parentContext);

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider<CartController>.value(
        value: cart, // re-provide SAME instance to the sheet
        child: SafeArea(
          child: Container(
            height: MediaQuery.of(parentContext).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5)),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Your Shopping Cart', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Divider(),
                Expanded(
                  child: Consumer<CartController>(
                    builder: (_, c, __) {
                      if (c.items.isEmpty) {
                        return const Center(child: Text('Your cart is empty. Start shopping!', style: TextStyle(color: Colors.black54)));
                      }
                      return ListView.builder(
                        itemCount: c.items.length,
                        itemBuilder: (_, i) {
                          final item = c.items[i];
                          return ListTile(
                            leading: (item['imageUrl'] != null)
                                ? Image.network(item['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                                : const Icon(Icons.shopping_bag),
                            title: Text('${item['name']}'),
                            subtitle: Text('S\$${(item['price'] as num).toDouble().toStringAsFixed(2)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => c.removeAt(i),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Consumer<CartController>(
                  builder: (_, c, __) => Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:', style: TextStyle(fontSize: 18)),
                          Text('S\$${c.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: c.items.isEmpty || profile == null
                              ? null
                              : () async {
                                  navigator.pop();
                                  await navigator.push(
                                    MaterialPageRoute(
                                      builder: (_) => PaymentConfirmationPage(
                                        totalAmount: c.subtotal,
                                        cartItems: c.items,
                                        userProfile: profile,
                                      ),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.pink.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Proceed to Checkout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.lightGreen.shade100,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.lightGreen.shade200, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Health Market', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A))),
              const SizedBox(height: 5),
              Text('Medication, supplements, self-care and more.',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.lightGreen.shade800)),
            ]),
          ),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.lightGreen.shade200, borderRadius: BorderRadius.circular(10)),
            child: Icon(FontAwesomeIcons.shoppingBag, color: Colors.lightGreen.shade700, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onAdd;
  const _MarketplaceTile({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            product['imageUrl'],
            width: 60, height: 60, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 60, height: 60, color: Colors.grey.shade300,
              child: const Icon(Icons.local_hospital, color: Colors.white),
            ),
          ),
        ),
        title: Text('${product['name']}', maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 2),
            Text('${product['description']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text('S\$${(product['price'] as num).toDouble().toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.pink.shade600)),
          ],
        ),
        trailing: IconButton(icon: const Icon(Icons.add_circle, color: Colors.lightGreen), onPressed: onAdd),
      ),
    );
  }
}

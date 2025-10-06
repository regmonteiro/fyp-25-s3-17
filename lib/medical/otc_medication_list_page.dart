import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../financial/payment_confirmation_page.dart';
import '../models/user_profile.dart';
import 'controller/cart_controller.dart';

class OTCMedicationListPage extends StatelessWidget {
  const OTCMedicationListPage({Key? key}) : super(key: key);

  static const List<Map<String, dynamic>> _otcProducts = [
    {
      'id': 'otc_001',
      'name': 'Panadol 500mg',
      'description': 'Relief of pain and fever.',
      'price': 9.95,
      'imageUrl': 'https://placehold.co/100x100/D97706/ffffff?text=Pain+Relief',
    },
    {
      'id': 'otc_002',
      'name': 'Immunity Vitamin C',
      'description': 'Supports immune system health.',
      'price': 6.00,
      'imageUrl': 'https://placehold.co/100x100/10B981/ffffff?text=Vitamin+C',
    },
    {
      'id': 'otc_003',
      'name': 'Gentle Laxative',
      'description': 'For gentle overnight relief.',
      'price': 15.50,
      'imageUrl': 'https://placehold.co/100x100/3B82F6/ffffff?text=Digestion',
    },
    {
      'id': 'otc_004',
      'name': 'Antiseptic Cream',
      'description': 'First aid for minor cuts and scrapes.',
      'price': 4.75,
      'imageUrl': 'https://placehold.co/100x100/EAB308/ffffff?text=Antiseptic',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTC Medication Shop'),
        backgroundColor: Colors.lightGreen.shade700,
        elevation: 0,
        actions: [
          Consumer<CartController>(
            builder: (context, cart, _) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () => _openCartSheet(context),
                ),
                if (cart.count > 0)
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('${cart.count}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // simple search placeholder
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search medication...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.72,
              ),
              itemCount: _otcProducts.length,
              itemBuilder: (context, i) => _ProductCard(product: _otcProducts[i]),
            ),
          ),
        ],
      ),
    );
  }

  void _openCartSheet(BuildContext parentContext) {
    final cart = parentContext.read<CartController>();    // shared
    final user = parentContext.read<UserProfile?>();      // may be null
    final navigator = Navigator.of(parentContext);

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider<CartController>.value(
        value: cart,
        child: SafeArea(
          child: Container(
            height: MediaQuery.of(parentContext).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
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
                        itemBuilder: (_, index) {
                          final item = c.items[index];
                          return ListTile(
                            leading: (item['imageUrl'] != null)
                                ? Image.network(item['imageUrl'], width: 50, height: 50, fit: BoxFit.cover)
                                : const Icon(Icons.medication_liquid),
                            title: Text('${item['name']}'),
                            subtitle: Text('S\$${(item['price'] as num).toDouble().toStringAsFixed(2)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => c.removeAt(index),
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
                          onPressed: c.items.isEmpty || user == null
                              ? null
                              : () async {
                                  navigator.pop();
                                  await navigator.push(
                                    MaterialPageRoute(
                                      builder: (_) => PaymentConfirmationPage(
                                        totalAmount: c.subtotal,
                                        cartItems: c.items,
                                        userProfile: user,
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
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartController>();
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Image.network(
              product['imageUrl'],
              height: 120, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120, color: Colors.grey.shade300,
                child: const Center(child: Icon(Icons.medication_liquid, size: 40, color: Colors.white)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${product['name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, height: 1.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${product['description']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('S\$${(product['price'] as num).toDouble().toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: Colors.pink.shade600, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart, color: Colors.lightGreen),
                      onPressed: () {
                        cart.add(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${product['name']} added to cart!'),
                            duration: const Duration(milliseconds: 800)),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

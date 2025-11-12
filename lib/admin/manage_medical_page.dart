import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'admin_shell.dart';
import '../models/user_profile.dart';
import 'admin_routes.dart';

class AdminManageMedical extends StatefulWidget {
  final UserProfile userProfile;
  const AdminManageMedical({Key? key, required this.userProfile})
    : super(key: key);

  @override
  _AdminManageMedicalState createState() => _AdminManageMedicalState();
}

class _AdminManageMedicalState extends State<AdminManageMedical> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // State variables
  bool _isLoading = false;
  String _searchQuery = '';
  List<MedicalProduct> _allProducts = [];
  List<MedicalProduct> _filteredProducts = [];
  List<MedicalOrder> _orders = [];
  ProductStats _productStats = ProductStats();

  // Form data
  final TextEditingController _searchController = TextEditingController();

  // Colors
  final Color _backgroundColor = const Color(0xFFf5f5f5);
  final Color _whiteColor = Colors.white;
  final Color _darkGrayColor = const Color(0xFF666666);
  final Color _purpleColor = Colors.purple.shade500;
  final Color _redColor = Colors.red;
  final Color _blueColor = Colors.blue;
  final Color _greenColor = Colors.green;
  final Color _orangeColor = Colors.orange;
  final Color _lightGrayColor = const Color(0xFFE0E0E0);

  static const String _TAG = "AdminManageMedical";
  static const String _COLLECTION_PRODUCTS = "MedicalProducts";

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _setupOrdersListener();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      profile: widget.userProfile,
      currentKey: 'adminManageMedical',
      title: 'Medical Products',
      body: _buildBody(),
      floatingActionButton: _buildAddButton(),
      showBackButton: true,
      onBackPressed: () =>
          navigateAdmin(context, 'adminDashboard', widget.userProfile),
      showDashboardButton: true,
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Header Section (search)
        _buildHeaderSection(),

        // Loading State
        if (_isLoading)
          Expanded(child: _buildLoadingState())
        else
          // Empty or Products Grid/List
          Expanded(
            child: _filteredProducts.isEmpty
                ? _buildEmptyState()
                : _buildProductsLayout(),
          ),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        _getResponsiveValue(mobile: 16, tablet: 20, desktop: 24),
      ),
      color: _whiteColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Create, edit, and manage medical products for elderly users",
            style: TextStyle(
              color: _darkGrayColor,
              fontSize: _getResponsiveValue(
                mobile: 12,
                tablet: 14,
                desktop: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: _getResponsiveValue(
                    mobile: 44,
                    tablet: 48,
                    desktop: 52,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search products...",
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: _getResponsiveValue(
                          mobile: 12,
                          tablet: 16,
                          desktop: 20,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filterProducts();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            "Loading products...",
            style: TextStyle(
              fontSize: _getResponsiveValue(
                mobile: 14,
                tablet: 16,
                desktop: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          _getResponsiveValue(mobile: 24, tablet: 32, desktop: 40),
        ),
        child: Text(
          _searchQuery.isEmpty
              ? "No products found. Create your first product to get started."
              : 'No products found matching "$_searchQuery"',
          style: TextStyle(
            fontSize: _getResponsiveValue(mobile: 14, tablet: 16, desktop: 18),
            color: _darkGrayColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildProductsLayout() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 600) {
      // Mobile - List view
      return _buildProductsList();
    } else if (screenWidth < 1200) {
      // Tablet - Grid with 2 columns
      return _buildProductsGrid(crossAxisCount: 2);
    } else {
      // Desktop - Grid with 3 columns
      return _buildProductsGrid(crossAxisCount: 3);
    }
  }

  Widget _buildProductsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) =>
          _buildProductListItem(_filteredProducts[index]),
    );
  }

  Widget _buildProductListItem(MedicalProduct product) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.all(
          _getResponsiveValue(mobile: 16, tablet: 20, desktop: 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              product.title,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Category
            Text(
              product.category,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  mobile: 14,
                  tablet: 16,
                  desktop: 18,
                ),
                color: _darkGrayColor,
              ),
            ),
            const SizedBox(height: 8),

            // Price Row
            Row(
              children: [
                // Current Price
                Expanded(
                  child: Text(
                    product.price,
                    style: TextStyle(
                      fontSize: _getResponsiveValue(
                        mobile: 16,
                        tablet: 18,
                        desktop: 20,
                      ),
                      fontWeight: FontWeight.bold,
                      color: _purpleColor,
                    ),
                  ),
                ),

                // Old Price (if exists)
                if (product.oldPrice != null && product.oldPrice!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      product.oldPrice!,
                      style: TextStyle(
                        fontSize: _getResponsiveValue(
                          mobile: 12,
                          tablet: 14,
                          desktop: 16,
                        ),
                        color: Color(0xFF999999),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),

                // Discount (if exists)
                if (product.discount != null && product.discount!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _getResponsiveValue(
                        mobile: 6,
                        tablet: 8,
                        desktop: 10,
                      ),
                      vertical: _getResponsiveValue(
                        mobile: 3,
                        tablet: 4,
                        desktop: 5,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: _redColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.discount!,
                      style: TextStyle(
                        fontSize: _getResponsiveValue(
                          mobile: 10,
                          tablet: 11,
                          desktop: 12,
                        ),
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Product Description
            Text(
              product.description,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                ),
                color: _darkGrayColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Buttons
            Container(
              height: 1,
              color: _lightGrayColor,
              margin: const EdgeInsets.symmetric(vertical: 12),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _editProduct(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purpleColor,
                      foregroundColor: _whiteColor,
                      padding: EdgeInsets.symmetric(
                        vertical: _getResponsiveValue(
                          mobile: 8,
                          tablet: 12,
                          desktop: 16,
                        ),
                      ),
                    ),
                    child: Text(
                      "Edit",
                      style: TextStyle(
                        fontSize: _getResponsiveValue(
                          mobile: 12,
                          tablet: 14,
                          desktop: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteProduct(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _redColor,
                      foregroundColor: _whiteColor,
                      padding: EdgeInsets.symmetric(
                        vertical: _getResponsiveValue(
                          mobile: 8,
                          tablet: 12,
                          desktop: 16,
                        ),
                      ),
                    ),
                    child: Text(
                      "Delete",
                      style: TextStyle(
                        fontSize: _getResponsiveValue(
                          mobile: 12,
                          tablet: 14,
                          desktop: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid({required int crossAxisCount}) {
    return GridView.builder(
      padding: EdgeInsets.all(
        _getResponsiveValue(mobile: 8, tablet: 12, desktop: 16),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: _getResponsiveValue(
          mobile: 8,
          tablet: 12,
          desktop: 16,
        ),
        mainAxisSpacing: _getResponsiveValue(
          mobile: 8,
          tablet: 12,
          desktop: 16,
        ),
        childAspectRatio: _getResponsiveValue(
          mobile: 0.7,
          tablet: 0.75,
          desktop: 0.8,
        ),
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (_, i) => _buildProductCard(_filteredProducts[i]),
    );
  }

  Widget _buildProductCard(MedicalProduct product) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.all(
          _getResponsiveValue(mobile: 12, tablet: 16, desktop: 20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              product.title,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Category
            Text(
              product.category,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                ),
                color: _darkGrayColor,
              ),
            ),
            const SizedBox(height: 8),

            // Price Row
            Row(
              children: [
                // Current Price
                Expanded(
                  child: Text(
                    product.price,
                    style: TextStyle(
                      fontSize: _getResponsiveValue(
                        mobile: 14,
                        tablet: 16,
                        desktop: 18,
                      ),
                      fontWeight: FontWeight.bold,
                      color: _purpleColor,
                    ),
                  ),
                ),

                // Discount (if exists)
                if (product.discount != null && product.discount!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _getResponsiveValue(
                        mobile: 4,
                        tablet: 6,
                        desktop: 8,
                      ),
                      vertical: _getResponsiveValue(
                        mobile: 2,
                        tablet: 3,
                        desktop: 4,
                      ),
                    ),
                    decoration: BoxDecoration(
                      color: _redColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.discount!,
                      style: TextStyle(
                        fontSize: _getResponsiveValue(
                          mobile: 9,
                          tablet: 10,
                          desktop: 11,
                        ),
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            // Old Price (if exists)
            if (product.oldPrice != null && product.oldPrice!.isNotEmpty)
              Text(
                product.oldPrice!,
                style: TextStyle(
                  fontSize: _getResponsiveValue(
                    mobile: 10,
                    tablet: 12,
                    desktop: 14,
                  ),
                  color: Color(0xFF999999),
                  decoration: TextDecoration.lineThrough,
                ),
              ),

            const Spacer(),

            // Product Description
            Text(
              product.description,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  mobile: 10,
                  tablet: 12,
                  desktop: 14,
                ),
                color: _darkGrayColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Buttons
            Container(
              height: 1,
              color: _lightGrayColor,
              margin: const EdgeInsets.symmetric(vertical: 12),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _editProduct(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purpleColor,
                      foregroundColor: _whiteColor,
                      padding: EdgeInsets.symmetric(
                        vertical: _getResponsiveValue(
                          mobile: 8,
                          tablet: 10,
                          desktop: 12,
                        ),
                      ),
                    ),
                    child: Text(
                      "Edit",
                      style: TextStyle(
                        fontSize: _getResponsiveValue(
                          mobile: 12,
                          tablet: 14,
                          desktop: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: _getResponsiveValue(mobile: 6, tablet: 8, desktop: 12),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _deleteProduct(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _redColor,
                      foregroundColor: _whiteColor,
                      padding: EdgeInsets.symmetric(
                        vertical: _getResponsiveValue(
                          mobile: 8,
                          tablet: 10,
                          desktop: 12,
                        ),
                      ),
                    ),
                    child: Text(
                      "Delete",
                      style: TextStyle(
                        fontSize: _getResponsiveValue(
                          mobile: 12,
                          tablet: 14,
                          desktop: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() => FloatingActionButton(
    onPressed: _createProduct,
    backgroundColor: _purpleColor,
    foregroundColor: _whiteColor,
    child: const Icon(Icons.add),
  );

  // Helper method to get responsive values
  double _getResponsiveValue({
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) {
      return mobile;
    } else if (screenWidth < 1200) {
      return tablet;
    } else {
      return desktop;
    }
  }

  // Data methods
  void _loadProducts() {
    print("Loading products from Firebase...");
    setState(() => _isLoading = true);

    _databaseRef
        .child(_COLLECTION_PRODUCTS)
        .onValue
        .listen(
          (event) {
            final snapshot = event.snapshot;
            print("=== PRODUCTS DATA RETRIEVED ===");
            print("Products snapshot exists: ${snapshot.exists}");

            List<MedicalProduct> loadedProducts = [];

            if (snapshot.value != null) {
              Map<dynamic, dynamic> productsData =
                  snapshot.value as Map<dynamic, dynamic>;

              productsData.forEach((key, value) {
                try {
                  // Skip non-product nodes
                  if (key == "orders" || key == "paymentMethods") {
                    print("Skipped non-product node: $key");
                    return;
                  }

                  Map<String, dynamic> productData = Map<String, dynamic>.from(
                    value as Map,
                  );
                  MedicalProduct product = MedicalProduct();
                  product.id = key.toString();

                  if (productData.containsKey("title")) {
                    product.title = productData["title"].toString();
                  }
                  if (productData.containsKey("description")) {
                    product.description = productData["description"].toString();
                  }
                  if (productData.containsKey("category")) {
                    product.category = productData["category"].toString();
                  }
                  if (productData.containsKey("price")) {
                    product.price = productData["price"].toString();
                  }
                  if (productData.containsKey("oldPrice")) {
                    dynamic oldPrice = productData["oldPrice"];
                    if (oldPrice != null) {
                      product.oldPrice = oldPrice.toString();
                    }
                  }
                  if (productData.containsKey("discount")) {
                    dynamic discount = productData["discount"];
                    if (discount != null) {
                      product.discount = discount.toString();
                    }
                  }
                  if (productData.containsKey("img")) {
                    product.img = productData["img"].toString();
                  }
                  if (productData.containsKey("createdAt")) {
                    product.createdAt = productData["createdAt"].toString();
                  }

                  loadedProducts.add(product);
                  print("Successfully loaded product: ${product.title}");
                } catch (e) {
                  print("Error parsing product: $e");
                }
              });
            }

            setState(() {
              _allProducts = loadedProducts;
              _filterProducts();
              _isLoading = false;
            });
            _calculateAnalytics();
          },
          onError: (error) {
            print("Error loading products: $error");
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Failed to load products")));
          },
        );
  }

  void _filterProducts() {
    final q = _searchQuery.toLowerCase().trim();
    _filteredProducts = q.isEmpty
        ? List.of(_allProducts)
        : _allProducts.where((p) {
            bool contains(String? s) => (s ?? '').toLowerCase().contains(q);
            return contains(p.title) ||
                contains(p.description) ||
                contains(p.category);
          }).toList();
    _filteredProducts.sort((a, b) => a.title.compareTo(b.title));
    setState(() {});
  }

  void _createProduct() {
    _showProductForm(null);
  }

  void _editProduct(MedicalProduct product) {
    _showProductForm(product);
  }

  void _showProductForm(MedicalProduct? product) {
    showDialog(
      context: context,
      builder: (_) =>
          ProductFormDialog(product: product, onSubmit: _submitProductForm),
    );
  }

  void _submitProductForm(
    String title,
    String description,
    String category,
    String price,
    String oldPrice,
    String discount,
    String image,
  ) async {
    setState(() => _isLoading = true);

    String formattedPrice = "S\$${double.parse(price).toStringAsFixed(2)}";
    String formattedOldPrice = oldPrice.isNotEmpty
        ? "S\$${double.parse(oldPrice).toStringAsFixed(2)}"
        : "";

    MedicalProduct product = MedicalProduct();
    product.title = title.trim();
    product.description = description.trim();
    product.category = category.trim();
    product.price = formattedPrice;
    product.oldPrice = formattedOldPrice.isNotEmpty ? formattedOldPrice : null;
    product.discount = discount.trim().isNotEmpty ? discount.trim() : null;
    product.img = image.trim();
    product.createdAt = DateTime.now().toString();

    try {
      if (product.id != null) {
        // Update existing product
        await _databaseRef
            .child(_COLLECTION_PRODUCTS)
            .child(product.id!)
            .set(product.toMap());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully')),
        );
      } else {
        // Create new product
        await _databaseRef
            .child(_COLLECTION_PRODUCTS)
            .push()
            .set(product.toMap());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product created successfully')),
        );
      }
      _loadProducts(); // Reload to get updated list
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save product: $e')));
    }
  }

  void _deleteProduct(MedicalProduct product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteProduct(product.id!);
            },
            child: Text('Delete', style: TextStyle(color: _redColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteProduct(String productId) async {
    setState(() => _isLoading = true);
    try {
      await _databaseRef.child(_COLLECTION_PRODUCTS).child(productId).remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
      _loadProducts();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete product: $e')));
    }
  }

  // Orders listener (simplified for this structure)
  void _setupOrdersListener() {
    print("Setting up real-time orders listener...");

    DatabaseReference ordersRef = _databaseRef
        .child("MedicalProducts")
        .child("orders");

    ordersRef.onValue.listen(
      (event) {
        print("=== ORDERS DATA UPDATED ===");

        List<MedicalOrder> loadedOrders = [];

        if (event.snapshot.value != null) {
          Map<dynamic, dynamic> ordersData =
              event.snapshot.value as Map<dynamic, dynamic>;

          ordersData.forEach((key, value) {
            try {
              Map<String, dynamic> orderData = Map<String, dynamic>.from(
                value as Map,
              );
              MedicalOrder order = MedicalOrder();
              order.id = key.toString();

              // Set basic order info
              if (orderData.containsKey("userEmail")) {
                order.userEmail = orderData["userEmail"].toString();
              }
              if (orderData.containsKey("createdAt")) {
                order.createdAt = orderData["createdAt"].toString();
              }
              if (orderData.containsKey("status")) {
                order.status = orderData["status"].toString();
              }
              if (orderData.containsKey("totalAmount")) {
                dynamic amount = orderData["totalAmount"];
                if (amount is double) {
                  order.totalAmount = amount;
                } else if (amount is int) {
                  order.totalAmount = amount.toDouble();
                } else if (amount is String) {
                  try {
                    order.totalAmount = double.parse(amount);
                  } catch (e) {
                    order.totalAmount = 0.0;
                  }
                }
              }

              // Parse order items
              if (orderData.containsKey("items")) {
                List<OrderItem> items = [];
                dynamic itemsObj = orderData["items"];
                if (itemsObj is List) {
                  List<dynamic> itemsList = itemsObj as List<dynamic>;
                  for (dynamic itemObj in itemsList) {
                    if (itemObj is Map) {
                      Map<String, dynamic> itemData = Map<String, dynamic>.from(
                        itemObj,
                      );
                      OrderItem item = OrderItem();
                      if (itemData.containsKey("id")) {
                        item.id = itemData["id"].toString();
                      }
                      if (itemData.containsKey("name")) {
                        item.name = itemData["name"].toString();
                      }
                      if (itemData.containsKey("category")) {
                        item.category = itemData["category"].toString();
                      }
                      if (itemData.containsKey("price")) {
                        dynamic price = itemData["price"];
                        if (price != null) {
                          item.price = price.toString();
                        }
                      }
                      if (itemData.containsKey("quantity")) {
                        dynamic quantity = itemData["quantity"];
                        if (quantity is int) {
                          item.quantity = quantity;
                        } else if (quantity is String) {
                          try {
                            item.quantity = int.parse(quantity);
                          } catch (e) {
                            item.quantity = 1;
                          }
                        }
                      }
                      if (itemData.containsKey("image")) {
                        dynamic image = itemData["image"];
                        if (image != null) {
                          item.image = image.toString();
                        }
                      }
                      items.add(item);
                    }
                  }
                }
                order.items = items;
              }

              // Parse delivery address
              if (orderData.containsKey("deliveryAddress")) {
                Map<String, dynamic> addressData = Map<String, dynamic>.from(
                  orderData["deliveryAddress"],
                );
                DeliveryAddress address = DeliveryAddress();
                if (addressData.containsKey("recipientName")) {
                  address.recipientName = addressData["recipientName"]
                      .toString();
                }
                if (addressData.containsKey("blockStreet")) {
                  address.blockStreet = addressData["blockStreet"].toString();
                }
                if (addressData.containsKey("unitNumber")) {
                  address.unitNumber = addressData["unitNumber"].toString();
                }
                if (addressData.containsKey("postalCode")) {
                  address.postalCode = addressData["postalCode"].toString();
                }
                order.deliveryAddress = address;
              }

              // Parse payment method
              if (orderData.containsKey("paymentMethod")) {
                Map<String, dynamic> paymentData = Map<String, dynamic>.from(
                  orderData["paymentMethod"],
                );
                PaymentMethod payment = PaymentMethod();
                if (paymentData.containsKey("method")) {
                  payment.method = paymentData["method"].toString();
                }
                if (paymentData.containsKey("amount")) {
                  dynamic amount = paymentData["amount"];
                  if (amount is double) {
                    payment.amount = amount;
                  } else if (amount is int) {
                    payment.amount = amount.toDouble();
                  } else if (amount is String) {
                    try {
                      payment.amount = double.parse(amount);
                    } catch (e) {
                      payment.amount = 0.0;
                    }
                  }
                }
                if (paymentData.containsKey("cardType")) {
                  payment.cardType = paymentData["cardType"].toString();
                }
                if (paymentData.containsKey("lastFour")) {
                  payment.lastFour = paymentData["lastFour"].toString();
                }
                order.paymentMethod = payment;
              }

              loadedOrders.add(order);
            } catch (e) {
              print("Error parsing order: $e");
            }
          });
        }

        // Sort orders by date (newest first)
        loadedOrders.sort((a, b) {
          try {
            return b.createdAt.compareTo(a.createdAt);
          } catch (e) {
            return 0;
          }
        });

        setState(() {
          _orders = loadedOrders;
        });
        _calculateAnalytics();
      },
      onError: (error) {
        print("Error loading orders: $error");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load orders")));
      },
    );
  }

  void _calculateAnalytics() {
    print("=== CALCULATING ANALYTICS ===");

    _productStats.totalProducts = _allProducts.length;
    _productStats.totalOrders = _orders.length;

    double totalRevenue = 0;
    for (MedicalOrder order in _orders) {
      totalRevenue += order.totalAmount;
    }
    _productStats.totalRevenue = totalRevenue;

    // Calculate popular products
    Map<String, ProductSales> productSalesMap = {};
    Map<String, CategorySales> categorySalesMap = {};

    // Create product map for category lookup
    Map<String, MedicalProduct> productMap = {};
    for (MedicalProduct product in _allProducts) {
      if (product.id != null) {
        productMap[product.id!] = product;
      }
    }

    for (MedicalOrder order in _orders) {
      if (order.items != null) {
        for (OrderItem item in order.items!) {
          String productId = item.id;
          MedicalProduct? product = productMap[productId];

          String category = "Uncategorized";
          String productName = item.name;

          if (product != null) {
            category = (product.category.isNotEmpty)
                ? product.category
                : "Uncategorized";
            productName = product.title;
          } else {
            category = item.category ?? "Uncategorized";
          }

          double itemPrice = _convertPriceToDouble(item.price);
          int quantity = item.quantity;

          // Product stats
          ProductSales productSales =
              productSalesMap[productId] ?? ProductSales(productName, category);
          productSales.totalSold += quantity;
          productSales.totalRevenue += itemPrice * quantity;
          productSalesMap[productId] = productSales;

          // Category stats
          CategorySales categorySales =
              categorySalesMap[category] ?? CategorySales(category);
          categorySales.totalSold += quantity;
          categorySales.totalRevenue += itemPrice * quantity;
          categorySalesMap[category] = categorySales;
        }
      }
    }

    _productStats.popularProducts = productSalesMap.values.toList();
    _productStats.popularProducts.sort(
      (a, b) => b.totalSold.compareTo(a.totalSold),
    );

    _productStats.popularCategories = categorySalesMap.values.toList();
    _productStats.popularCategories.sort(
      (a, b) => b.totalRevenue.compareTo(a.totalRevenue),
    );

    print(
      "Analytics calculated - Products: ${_productStats.totalProducts}, "
      "Orders: ${_productStats.totalOrders}, Revenue: ${_productStats.totalRevenue}",
    );

    setState(() {});
  }

  double _convertPriceToDouble(String priceStr) {
    if (priceStr.isEmpty) return 0.0;
    try {
      String cleanPrice = priceStr
          .replaceAll("S\$", "")
          .replaceAll(RegExp(r'[^\d.]'), '');
      return double.parse(cleanPrice);
    } catch (e) {
      return 0.0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Product Form Dialog
class ProductFormDialog extends StatefulWidget {
  final MedicalProduct? product;
  final Function(
    String title,
    String description,
    String category,
    String price,
    String oldPrice,
    String discount,
    String image,
  )
  onSubmit;

  const ProductFormDialog({Key? key, this.product, required this.onSubmit})
    : super(key: key);

  @override
  _ProductFormDialogState createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _oldPriceController = TextEditingController();
  final _discountController = TextEditingController();
  final _imageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _titleController.text = widget.product!.title;
      _descriptionController.text = widget.product!.description;
      _categoryController.text = widget.product!.category;

      String price = widget.product!.price;
      if (price.startsWith("S\$")) {
        price = price.substring(2);
      }
      _priceController.text = price;

      if (widget.product!.oldPrice != null &&
          widget.product!.oldPrice!.isNotEmpty) {
        String oldPrice = widget.product!.oldPrice!;
        if (oldPrice.startsWith("S\$")) {
          oldPrice = oldPrice.substring(2);
        }
        _oldPriceController.text = oldPrice;
      }

      if (widget.product!.discount != null) {
        _discountController.text = widget.product!.discount!;
      }

      _imageController.text = widget.product!.img;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Form(
        key: _formKey,
        child: Container(
          padding: EdgeInsets.all(20),
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.product != null
                      ? "Edit Product"
                      : "Create New Product",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                _buildFormField(
                  "Title *",
                  _titleController,
                  "Enter product title",
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Title is required' : null,
                ),

                _buildFormField(
                  "Description *",
                  _descriptionController,
                  "Enter product description",
                  maxLines: 3,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Description is required'
                      : null,
                ),

                _buildFormField(
                  "Category *",
                  _categoryController,
                  "e.g., Pain Relief, Vitamins",
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Category is required' : null,
                ),

                _buildFormField(
                  "Price (S\$) *",
                  _priceController,
                  "0.00",
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Price is required';
                    if (double.tryParse(v) == null || double.parse(v) <= 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),

                _buildFormField(
                  "Old Price (S\$)",
                  _oldPriceController,
                  "0.00",
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),

                _buildFormField(
                  "Discount",
                  _discountController,
                  "e.g., 20% OFF",
                ),

                _buildFormField(
                  "Image URL *",
                  _imageController,
                  "https://example.com/image.jpg",
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Image URL is required' : null,
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        child: Text(
                          widget.product != null
                              ? "Update Product"
                              : "Create Product",
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller,
    String hintText, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
          validator: validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _categoryController.text.trim(),
        _priceController.text.trim(),
        _oldPriceController.text.trim(),
        _discountController.text.trim(),
        _imageController.text.trim(),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _oldPriceController.dispose();
    _discountController.dispose();
    _imageController.dispose();
    super.dispose();
  }
}

// Model Classes
class MedicalProduct {
  String? id;
  String title = "";
  String description = "";
  String category = "";
  String price = "";
  String? oldPrice;
  String? discount;
  String img = "";
  String createdAt = "";

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      if (oldPrice != null) 'oldPrice': oldPrice,
      if (discount != null) 'discount': discount,
      'img': img,
      'createdAt': createdAt,
    };
  }
}

class MedicalOrder {
  String? id;
  String userEmail = "";
  String createdAt = "";
  String status = "";
  double totalAmount = 0.0;
  List<OrderItem>? items;
  DeliveryAddress? deliveryAddress;
  PaymentMethod? paymentMethod;
}

class OrderItem {
  String id = "";
  String name = "";
  String? category;
  String price = "";
  int quantity = 0;
  String? image;
}

class DeliveryAddress {
  String recipientName = "";
  String blockStreet = "";
  String unitNumber = "";
  String postalCode = "";
}

class PaymentMethod {
  String method = "";
  double amount = 0.0;
  String? cardType;
  String? lastFour;
}

class ProductStats {
  int totalProducts = 0;
  int totalOrders = 0;
  double totalRevenue = 0.0;
  List<ProductSales> popularProducts = [];
  List<CategorySales> popularCategories = [];
}

class ProductSales {
  String name;
  String category;
  int totalSold;
  double totalRevenue;

  ProductSales(this.name, this.category) : totalSold = 0, totalRevenue = 0.0;
}

class CategorySales {
  String name;
  int totalSold;
  double totalRevenue;

  CategorySales(this.name) : totalSold = 0, totalRevenue = 0.0;
}

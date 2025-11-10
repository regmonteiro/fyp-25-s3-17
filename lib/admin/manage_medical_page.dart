import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminManageMedical extends StatefulWidget {
  @override
  _AdminManageMedicalState createState() => _AdminManageMedicalState();
}

class _AdminManageMedicalState extends State<AdminManageMedical> with SingleTickerProviderStateMixin {
  static const String TAG = "AdminManageMedical";

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  late TabController _tabController;
  bool _isLoading = false;
  MedicalProduct? _editingProduct;

  // Data lists
  List<MedicalProduct> _products = [];
  List<MedicalOrder> _orders = [];
  ProductStats _productStats = ProductStats();

  // UI State
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadData();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    _loadProducts();
    _setupOrdersListener();
  }

  void _loadProducts() {
    print("Loading products from Firebase...");

    _databaseRef.child("MedicalProducts").onValue.listen((event) {
      final snapshot = event.snapshot;
      print("=== PRODUCTS DATA RETRIEVED ===");
      print("Products snapshot exists: ${snapshot.exists}");

      List<MedicalProduct> loadedProducts = [];

      if (snapshot.value != null) {
        Map<dynamic, dynamic> productsData = snapshot.value as Map<dynamic, dynamic>;

        productsData.forEach((key, value) {
          try {
            // Skip non-product nodes
            if (key == "orders" || key == "paymentMethods") {
              print("Skipped non-product node: $key");
              return;
            }

            Map<String, dynamic> productData = Map<String, dynamic>.from(value as Map);
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
        _products = loadedProducts;
      });
      _calculateAnalytics();
    }, onError: (error) {
      print("Error loading products: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load products")),
      );
    });
  }

  void _setupOrdersListener() {
    print("Setting up real-time orders listener...");

    DatabaseReference ordersRef = _databaseRef.child("MedicalProducts").child("orders");

    ordersRef.onValue.listen((event) {
      print("=== ORDERS DATA UPDATED ===");

      List<MedicalOrder> loadedOrders = [];

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> ordersData = event.snapshot.value as Map<dynamic, dynamic>;

        ordersData.forEach((key, value) {
          try {
            Map<String, dynamic> orderData = Map<String, dynamic>.from(value as Map);
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
                    Map<String, dynamic> itemData = Map<String, dynamic>.from(itemObj);
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
              Map<String, dynamic> addressData = Map<String, dynamic>.from(orderData["deliveryAddress"]);
              DeliveryAddress address = DeliveryAddress();
              if (addressData.containsKey("recipientName")) {
                address.recipientName = addressData["recipientName"].toString();
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
              Map<String, dynamic> paymentData = Map<String, dynamic>.from(orderData["paymentMethod"]);
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
          // Using simple string comparison since we don't have intl package
          return b.createdAt.compareTo(a.createdAt);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        _orders = loadedOrders;
      });
      _calculateAnalytics();
    }, onError: (error) {
      print("Error loading orders: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load orders")),
      );
    });
  }

  void _calculateAnalytics() {
    print("=== CALCULATING ANALYTICS ===");

    _productStats.totalProducts = _products.length;
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
    for (MedicalProduct product in _products) {
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
          ProductSales productSales = productSalesMap[productId] ?? ProductSales(productName, category);
          productSales.totalSold += quantity;
          productSales.totalRevenue += itemPrice * quantity;
          productSalesMap[productId] = productSales;

          // Category stats
          CategorySales categorySales = categorySalesMap[category] ?? CategorySales(category);
          categorySales.totalSold += quantity;
          categorySales.totalRevenue += itemPrice * quantity;
          categorySalesMap[category] = categorySales;
        }
      }
    }

    _productStats.popularProducts = productSalesMap.values.toList();
    _productStats.popularProducts.sort((a, b) => b.totalSold.compareTo(a.totalSold));

    _productStats.popularCategories = categorySalesMap.values.toList();
    _productStats.popularCategories.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    print("Analytics calculated - Products: ${_productStats.totalProducts}, "
        "Orders: ${_productStats.totalOrders}, Revenue: ${_productStats.totalRevenue}");

    setState(() {});
  }

  double _convertPriceToDouble(String priceStr) {
    if (priceStr.isEmpty) return 0.0;
    try {
      String cleanPrice = priceStr.replaceAll("S\$", "").replaceAll(RegExp(r'[^\d.]'), '');
      return double.parse(cleanPrice);
    } catch (e) {
      return 0.0;
    }
  }

  // Product Management Methods
  void _showAddProductDialog() {
    _showProductForm(null);
  }

  void _showProductForm(MedicalProduct? product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProductFormDialog(
          product: product,
          onSave: (newProduct) {
            if (product == null) {
              _addProduct(newProduct);
            } else {
              _updateProduct(product.id!, newProduct);
            }
          },
        );
      },
    );
  }

  bool _validateProductForm(String title, String description, String category, String price, String image) {
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter product title")),
      );
      return false;
    }
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter product description")),
      );
      return false;
    }
    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter product category")),
      );
      return false;
    }
    if (price.isEmpty || double.tryParse(price) == null || double.parse(price) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid price")),
      );
      return false;
    }
    if (image.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter product image URL or filename")),
      );
      return false;
    }
    return true;
  }

  void _addProduct(MedicalProduct product) {
    setState(() {
      _isLoading = true;
    });

    _databaseRef.child("MedicalProducts").push().set(product.toMap())
        .then((_) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Product added successfully!")),
      );
    }).catchError((error) {
      setState(() {
        _isLoading = false;
      });
      print("Failed to add product: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add product")),
      );
    });
  }

  void _updateProduct(String productId, MedicalProduct product) {
    setState(() {
      _isLoading = true;
    });

    _databaseRef.child("MedicalProducts").child(productId).set(product.toMap())
        .then((_) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Product updated successfully!")),
      );
    }).catchError((error) {
      setState(() {
        _isLoading = false;
      });
      print("Failed to update product: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update product")),
      );
    });
  }

  void _deleteProduct(MedicalProduct product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Product"),
          content: Text('Are you sure you want to delete "${product.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performDeleteProduct(product);
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _performDeleteProduct(MedicalProduct product) {
    setState(() {
      _isLoading = true;
    });

    _databaseRef.child("MedicalProducts").child(product.id!).remove()
        .then((_) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Product deleted successfully!")),
      );
    }).catchError((error) {
      setState(() {
        _isLoading = false;
      });
      print("Failed to delete product: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete product")),
      );
    });
  }

  void _updateOrderStatus(MedicalOrder order, String newStatus) {
    setState(() {
      _isLoading = true;
    });

    _databaseRef.child("MedicalProducts").child("orders").child(order.id!).child("status")
        .set(newStatus)
        .then((_) {
      setState(() {
        _isLoading = false;
        order.status = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Order status updated successfully!")),
      );
    }).catchError((error) {
      setState(() {
        _isLoading = false;
      });
      print("Failed to update order status: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update order status")),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Medical Products"),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Products"),
            Tab(text: "Orders"),
            Tab(text: "Analytics"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          // Products Tab
          _buildProductsView(),
          // Orders Tab
          _buildOrdersView(),
          // Analytics Tab
          _buildAnalyticsView(),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0 ? FloatingActionButton(
        onPressed: _showAddProductDialog,
        child: Icon(Icons.add),
        backgroundColor: Colors.purple,
      ) : null,
    );
  }

  Widget _buildProductsView() {
    if (_products.isEmpty) {
      return Center(
        child: Text(
          "No products available",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        MedicalProduct product = _products[index];
        return MedicalProductCard(
          product: product,
          onEdit: () => _showProductForm(product),
          onDelete: () => _deleteProduct(product),
        );
      },
    );
  }

  Widget _buildOrdersView() {
    if (_orders.isEmpty) {
      return Center(
        child: Text(
          "No orders available",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        MedicalOrder order = _orders[index];
        return MedicalOrderCard(
          order: order,
          onStatusChanged: (newStatus) => _updateOrderStatus(order, newStatus),
        );
      },
    );
  }

  Widget _buildAnalyticsView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  "Total Products",
                  _productStats.totalProducts.toString(),
                  Colors.blue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  "Total Orders",
                  _productStats.totalOrders.toString(),
                  Colors.green,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  "Total Revenue",
                  "S\$${_productStats.totalRevenue.toStringAsFixed(2)}",
                  Colors.purple,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),

          // Popular Products
          Text("Popular Products", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          _buildPopularProductsList(),
          SizedBox(height: 24),

          // Popular Categories
          Text("Popular Categories", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          _buildPopularCategoriesList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularProductsList() {
    if (_productStats.popularProducts.isEmpty) {
      return Center(
        child: Text(
          "No popular products data",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _productStats.popularProducts.map((productSales) {
        return AnalyticsCard(
          title: productSales.name,
          value: productSales.totalSold.toString(),
          subtitle: "Revenue: S\$${productSales.totalRevenue.toStringAsFixed(2)}",
        );
      }).toList(),
    );
  }

  Widget _buildPopularCategoriesList() {
    if (_productStats.popularCategories.isEmpty) {
      return Center(
        child: Text(
          "No popular categories data",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _productStats.popularCategories.map((categorySales) {
        return AnalyticsCard(
          title: categorySales.name,
          value: categorySales.totalSold.toString(),
          subtitle: "Revenue: S\$${categorySales.totalRevenue.toStringAsFixed(2)}",
        );
      }).toList(),
    );
  }
}

// Medical Product Card Widget
class MedicalProductCard extends StatelessWidget {
  final MedicalProduct product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MedicalProductCard({
    Key? key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Title
            Text(
              product.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 4),

            // Product Category
            Text(
              product.category,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            SizedBox(height: 8),

            // Price Row
            Row(
              children: [
                // Current Price
                Expanded(
                  child: Text(
                    product.price,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
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
                        fontSize: 14,
                        color: Color(0xFF999999),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),

                // Discount (if exists)
                if (product.discount != null && product.discount!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.discount!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),

            // Product Description
            Text(
              product.description,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 12),

            // Edit/Delete Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Edit"),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Delete"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Medical Order Card Widget
class MedicalOrderCard extends StatefulWidget {
  final MedicalOrder order;
  final Function(String) onStatusChanged;

  const MedicalOrderCard({
    Key? key,
    required this.order,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  _MedicalOrderCardState createState() => _MedicalOrderCardState();
}

class _MedicalOrderCardState extends State<MedicalOrderCard> {
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending": return Colors.orange;
      case "confirmed": return Colors.blue;
      case "shipped": return Colors.green;
      case "delivered": return Colors.green;
      case "cancelled": return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    // Simple date formatting without intl package
    try {
      // Try to parse the date string directly
      return dateString;
    } catch (e) {
      return dateString;
    }
  }

  double _convertPriceToDouble(String priceStr) {
    if (priceStr.isEmpty) return 0.0;
    try {
      String cleanPrice = priceStr.replaceAll("S\$", "").replaceAll(RegExp(r'[^\d.]'), '');
      return double.parse(cleanPrice);
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Order #${widget.order.id!.substring(0, widget.order.id!.length < 8 ? widget.order.id!.length : 8)}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.order.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.order.status,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),

            // Order Email
            Text(
              widget.order.userEmail,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            SizedBox(height: 2),

            // Order Date
            Text(
              _formatDate(widget.order.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF999999),
              ),
            ),

            // Order Items Section
            SizedBox(height: 12),
            Text(
              "Order Items:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 8),
            _buildOrderItems(),

            // Order Summary
            SizedBox(height: 8),
            _buildOrderSummary(),

            // Delivery Address Section
            SizedBox(height: 12),
            Text(
              "Delivery Address:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 4),
            _buildDeliveryAddress(),

            // Payment Method Section
            SizedBox(height: 12),
            Text(
              "Payment Method:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 4),
            _buildPaymentMethod(),

            // Status Spinner
            SizedBox(height: 16),
            _buildStatusSpinner(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems() {
    if (widget.order.items == null || widget.order.items!.isEmpty) {
      return Container(
        padding: EdgeInsets.all(8),
        color: Color(0xFFf8f8f8),
        child: Center(
          child: Text(
            "No items in this order",
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ),
      );
    }

    double itemsTotal = 0.0;
    List<Widget> itemWidgets = [];

    for (OrderItem item in widget.order.items!) {
      double itemPrice = _convertPriceToDouble(item.price);
      double itemTotal = itemPrice * item.quantity;
      itemsTotal += itemTotal;

      itemWidgets.add(Text(
        "• ${item.name} - Qty: ${item.quantity} - S\$${itemTotal.toStringAsFixed(2)}",
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF666666),
        ),
      ));
    }

    return Container(
      padding: EdgeInsets.all(8),
      color: Color(0xFFf8f8f8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: itemWidgets,
      ),
    );
  }

  Widget _buildOrderSummary() {
    double itemsTotal = 0.0;
    if (widget.order.items != null) {
      for (OrderItem item in widget.order.items!) {
        double itemPrice = _convertPriceToDouble(item.price);
        itemsTotal += itemPrice * item.quantity;
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Items Total:",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                ),
              ),
            ),
            Text(
              "S\$${itemsTotal.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          "Total: S\$${widget.order.totalAmount.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryAddress() {
    if (widget.order.deliveryAddress == null) {
      return Container(
        padding: EdgeInsets.all(8),
        child: Center(
          child: Text(
            "No delivery address provided",
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ),
      );
    }

    DeliveryAddress address = widget.order.deliveryAddress!;
    List<Widget> addressWidgets = [];

    if (address.recipientName.isNotEmpty) {
      addressWidgets.add(Text(
        address.recipientName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ));
    }
    if (address.blockStreet.isNotEmpty) {
      addressWidgets.add(Text(
        address.blockStreet,
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF666666),
        ),
      ));
    }
    if (address.unitNumber.isNotEmpty) {
      addressWidgets.add(Text(
        address.unitNumber,
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF666666),
        ),
      ));
    }
    if (address.postalCode.isNotEmpty) {
      addressWidgets.add(Text(
        address.postalCode,
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF666666),
        ),
      ));
    }

    return Container(
      padding: EdgeInsets.all(8),
      color: Color(0xFFf8f8f8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: addressWidgets.isEmpty
            ? [Text("No delivery address details", style: TextStyle(color: Color(0xFF999999)))]
            : addressWidgets,
      ),
    );
  }

  Widget _buildPaymentMethod() {
    if (widget.order.paymentMethod == null) {
      return Container(
        padding: EdgeInsets.all(8),
        child: Center(
          child: Text(
            "No payment method details",
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ),
      );
    }

    PaymentMethod payment = widget.order.paymentMethod!;
    List<Widget> paymentWidgets = [];

    if (payment.method.isNotEmpty) {
      paymentWidgets.add(Text(
        payment.method,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ));
    }
    if (payment.cardType != null && payment.cardType!.isNotEmpty) {
      paymentWidgets.add(Text(
        payment.cardType!,
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF666666),
        ),
      ));
    }
    if (payment.lastFour != null && payment.lastFour!.isNotEmpty) {
      paymentWidgets.add(Text(
        "Card: **** ${payment.lastFour!}",
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF666666),
        ),
      ));
    }
    paymentWidgets.add(Text(
      "Amount: S\$${payment.amount.toStringAsFixed(2)}",
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.purple,
      ),
    ));

    return Container(
      padding: EdgeInsets.all(8),
      color: Color(0xFFf8f8f8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paymentWidgets,
      ),
    );
  }

  Widget _buildStatusSpinner() {
    List<String> statusOptions = ["Pending", "Confirmed", "Shipped", "Delivered", "Cancelled"];

    return DropdownButtonFormField<String>(
      value: _selectedStatus,
      items: statusOptions.map((String status) {
        return DropdownMenuItem<String>(
          value: status,
          child: Text(status),
        );
      }).toList(),
      onChanged: (String? newStatus) {
        if (newStatus != null && newStatus != _selectedStatus) {
          setState(() {
            _selectedStatus = newStatus;
          });
          widget.onStatusChanged(newStatus);
        }
      },
      decoration: InputDecoration(
        labelText: "Update Status",
        border: OutlineInputBorder(),
      ),
    );
  }
}

// Analytics Card Widget
class AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const AnalyticsCard({
    Key? key,
    required this.title,
    required this.value,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(4),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Product Form Dialog
class ProductFormDialog extends StatefulWidget {
  final MedicalProduct? product;
  final Function(MedicalProduct) onSave;

  const ProductFormDialog({Key? key, this.product, required this.onSave}) : super(key: key);

  @override
  _ProductFormDialogState createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _oldPriceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();

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

      if (widget.product!.oldPrice != null && widget.product!.oldPrice!.isNotEmpty) {
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
    return AlertDialog(
      title: Text(widget.product == null ? "Add New Product" : "Edit Product"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Product Title *"),
              SizedBox(height: 4),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(hintText: "Enter product title"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter product title";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text("Category *"),
              SizedBox(height: 4),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(hintText: "e.g., Pain Relief, Vitamins"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter product category";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text("Description *"),
              SizedBox(height: 4),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(hintText: "Enter product description"),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter product description";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text("Price (S\$) *"),
              SizedBox(height: 4),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(hintText: "0.00"),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter a valid price";
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return "Please enter a valid price";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              Text("Old Price (S\$)"),
              SizedBox(height: 4),
              TextFormField(
                controller: _oldPriceController,
                decoration: InputDecoration(hintText: "0.00"),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 16),
              Text("Discount"),
              SizedBox(height: 4),
              TextFormField(
                controller: _discountController,
                decoration: InputDecoration(hintText: "e.g., 20% OFF"),
              ),
              SizedBox(height: 16),
              Text("Image URL or Filename *"),
              SizedBox(height: 4),
              TextFormField(
                controller: _imageController,
                decoration: InputDecoration(hintText: "https://example.com/image.jpg OR product-image.png"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter product image URL or filename";
                  }
                  return null;
                },
              ),
              if (widget.product != null && widget.product!.img.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  "Current Image: ${widget.product!.img}",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _saveProduct,
          child: Text(widget.product == null ? "Add Product" : "Update Product"),
        ),
      ],
    );
  }

  void _saveProduct() {
    if (_formKey.currentState!.validate()) {
      String formattedPrice = "S\$${double.parse(_priceController.text).toStringAsFixed(2)}";
      String formattedOldPrice = _oldPriceController.text.isNotEmpty
          ? "S\$${double.parse(_oldPriceController.text).toStringAsFixed(2)}"
          : "";

      MedicalProduct product = MedicalProduct();
      product.title = _titleController.text.trim();
      product.description = _descriptionController.text.trim();
      product.category = _categoryController.text.trim();
      product.price = formattedPrice;
      product.oldPrice = formattedOldPrice.isNotEmpty ? formattedOldPrice : null;
      product.discount = _discountController.text.trim().isNotEmpty ? _discountController.text.trim() : null;
      product.img = _imageController.text.trim();
      product.createdAt = DateTime.now().toString();

      widget.onSave(product);
      Navigator.of(context).pop();
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

// Model Classes (Same structure as Java)
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

  ProductSales(this.name, this.category)
      : totalSold = 0,
        totalRevenue = 0.0;
}

class CategorySales {
  String name;
  int totalSold;
  double totalRevenue;

  CategorySales(this.name)
      : totalSold = 0,
        totalRevenue = 0.0;
}
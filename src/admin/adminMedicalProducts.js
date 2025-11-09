// components/AdminPanel.js
import React, { useState, useEffect, useCallback } from 'react';
import { getDatabase, ref, get, set, push, onValue, off } from "firebase/database";
import { MedicalProductsController } from '../controller/medicalproductsController';
import { OrderService } from '../entity/orderServiceEntity';
import './adminMedicalProducts.css';

// Helper function to handle both URL and local image paths
const getImagePath = (imageNameOrUrl) => {
  // If it's already a full URL (http/https), return as is
  if (imageNameOrUrl?.startsWith('http')) {
    return imageNameOrUrl;
  }
  
  // If it's a base64 image, return as is
  if (imageNameOrUrl?.startsWith('data:')) {
    return imageNameOrUrl;
  }
  
  // If it's a local image path that's already processed by require, return the default
  if (imageNameOrUrl?.includes('static/media/')) {
    return imageNameOrUrl;
  }
  
  if (imageNameOrUrl) {
    try {
      const imageModule = require(`../elderly/medicineandproductimages/${imageNameOrUrl}`);
      return imageModule.default || imageModule;
    } catch (error) {
      console.log(`Image not found: ${imageNameOrUrl}`);
    }
  }
  
  // Fallback placeholder image
  return "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5JbWFnZSBub3QgYXZhaWxhYmxlPC90ZXh0Pjwvc3ZnPg==";
};

const AdminMedicalProducts = () => {
  const [activeTab, setActiveTab] = useState('products');
  const [products, setProducts] = useState([]);
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(false);
  const [showProductForm, setShowProductForm] = useState(false);
  const [editingProduct, setEditingProduct] = useState(null);
  const [productStats, setProductStats] = useState({});
  const [imagePreview, setImagePreview] = useState('');

  const [productForm, setProductForm] = useState({
    title: '',
    description: '',
    category: '',
    price: '',
    oldPrice: '',
    discount: '',
    img: ''
  });

  const productsController = new MedicalProductsController();
  // FIX: Remove user email for admin - admin should see ALL orders
  const orderService = new OrderService();

  // Use useCallback to memoize loadData and prevent unnecessary re-renders
  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      if (activeTab === 'products') {
        await loadProducts();
      } else if (activeTab === 'analytics') {
        await loadAnalytics();
      }
      // Note: orders are now handled by the real-time listener below
    } catch (error) {
      console.error('Error loading data:', error);
      alert('Failed to load data');
    } finally {
      setLoading(false);
    }
  }, [activeTab]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Real-time listener for orders - only loads when orders tab is active
  useEffect(() => {
    if (activeTab === 'orders') {
      setLoading(true);
      const db = getDatabase();
      const ordersRef = ref(db, 'MedicalProducts/orders');
      
      const unsubscribe = onValue(ordersRef, (snapshot) => {
        if (snapshot.exists()) {
          const ordersData = snapshot.val();
          const allOrders = [];
          
          Object.keys(ordersData).forEach(key => {
            const order = ordersData[key];
            
            // FIX: Show ALL orders without email filtering for admin
            if (order) {
              allOrders.push({
                id: key,
                userEmail: order.userEmail || 'Unknown',
                createdAt: order.createdAt || new Date().toISOString(),
                status: order.status || 'pending',
                totalAmount: order.totalAmount || 0,
                items: Array.isArray(order.items) ? order.items.map(item => ({
                  ...item,
                  displayImage: getImagePath(item.image),
                  id: item.id || 'unknown',
                  name: item.name || 'Unknown Product',
                  price: item.price || 0,
                  quantity: item.quantity || 1
                })) : [],
                deliveryAddress: order.deliveryAddress || {
                  recipientName: 'Unknown',
                  blockStreet: 'Unknown',
                  unitNumber: 'Unknown',
                  postalCode: 'Unknown'
                },
                paymentMethod: order.paymentMethod || {
                  method: 'unknown',
                  amount: order.totalAmount || 0
                }
              });
            }
          });
          
          // Sort orders by date (newest first)
          allOrders.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
          setOrders(allOrders);
        } else {
          setOrders([]);
        }
        setLoading(false);
      }, (error) => {
        console.error('Error in orders listener:', error);
        setLoading(false);
      });

      // Cleanup function - remove listener when tab changes or component unmounts
      return () => unsubscribe();
    } else {
      // If not on orders tab, clear orders to free memory
      setOrders([]);
    }
  }, [activeTab]);

  // Add cleanup for Firebase listeners when component unmounts
  useEffect(() => {
    return () => {
      const db = getDatabase();
      const ordersRef = ref(db, 'MedicalProducts/orders');
      off(ordersRef);
    };
  }, []);

  // Update image preview when img field changes
  useEffect(() => {
    if (productForm.img) {
      setImagePreview(getImagePath(productForm.img));
    } else {
      setImagePreview('');
    }
  }, [productForm.img]);

  const loadProducts = async () => {
    const result = await productsController.getAllProducts();
    if (result.success) {
      // Process products to ensure images are loaded correctly
      const processedProducts = result.data.map(product => ({
        ...product,
        displayImg: getImagePath(product.img)
      }));
      setProducts(processedProducts);
    } else {
      alert('Failed to load products: ' + result.error);
    }
  };

  const loadAnalytics = async () => {
    try {
      const productsResult = await productsController.getAllProducts();
      
      // Load orders directly for analytics using getAllOrders() for admin
      const allOrders = await orderService.getAllOrders();
      
      // Ensure orders have proper structure
      const processedOrders = allOrders.map(order => ({
        ...order,
        items: order.items || [],
        totalAmount: order.totalAmount || 0
      }));

      if (productsResult.success) {
        // Ensure products have proper structure
        const processedProducts = productsResult.data.map(product => ({
          ...product,
          category: product.category || 'Uncategorized'
        }));
        
        const stats = calculateProductStats(processedProducts, processedOrders);
        setProductStats(stats);
      }
    } catch (error) {
      console.error('Error loading analytics:', error);
    }
  };

  const calculateProductStats = (products, orders) => {
    const productSales = {};
    const categorySales = {};

    // Create a proper product map for looking up categories
    const productMap = {};
    products.forEach(product => {
      if (product && product.id) {
        productMap[product.id] = {
          category: product.category && product.category.trim() !== '' ? product.category : 'Uncategorized',
          name: product.title || 'Unknown Product'
        };
      }
    });

    console.log('Product Map:', productMap);
    console.log('Orders:', orders);

    // Calculate product sales from orders
    orders.forEach(order => {
      if (order && order.items && Array.isArray(order.items)) {
        order.items.forEach(item => {
          if (!item || !item.id) return;
          
          const productId = item.id;
          const productInfo = productMap[productId] || {
            category: 'Uncategorized',
            name: item.name || 'Unknown Product'
          };
          
          // Use the category from product info, fallback to item category, then 'Uncategorized'
          const category = productInfo.category || item.category || 'Uncategorized';
          const itemName = productInfo.name || item.name || 'Unknown Product';
          const quantity = item.quantity || 1;
          const price = parseFloat(item.price || 0);

          // Product stats
          if (!productSales[productId]) {
            productSales[productId] = {
              name: itemName,
              totalSold: 0,
              totalRevenue: 0,
              category: category
            };
          }
          productSales[productId].totalSold += quantity;
          productSales[productId].totalRevenue += price * quantity;

          // Category stats
          if (!categorySales[category]) {
            categorySales[category] = {
              totalSold: 0,
              totalRevenue: 0
            };
          }
          categorySales[category].totalSold += quantity;
          categorySales[category].totalRevenue += price * quantity;
        });
      }
    });

    console.log('Category Sales:', categorySales);

    // Sort products by sales
    const popularProducts = Object.entries(productSales)
      .map(([id, data]) => ({
        id,
        ...data
      }))
      .sort((a, b) => b.totalSold - a.totalSold);

    // Sort categories by revenue and filter out empty ones
    const popularCategories = Object.entries(categorySales)
      .map(([name, data]) => ({
        name,
        ...data
      }))
      .filter(category => category.totalSold > 0) // Only show categories with sales
      .sort((a, b) => b.totalRevenue - a.totalRevenue);

    return {
      totalProducts: products.length,
      totalOrders: orders.length,
      totalRevenue: orders.reduce((sum, order) => sum + parseFloat(order.totalAmount || 0), 0),
      popularProducts,
      popularCategories
    };
  };

  const handleProductInputChange = (field, value) => {
    setProductForm(prev => ({
      ...prev,
      [field]: value
    }));
  };

  const resetProductForm = () => {
    setProductForm({
      title: '',
      description: '',
      category: '',
      price: '',
      oldPrice: '',
      discount: '',
      img: ''
    });
    setImagePreview('');
    setEditingProduct(null);
  };

  const validateProductForm = () => {
    if (!productForm.title.trim()) {
      alert('Please enter product title');
      return false;
    }
    if (!productForm.description.trim()) {
      alert('Please enter product description');
      return false;
    }
    if (!productForm.category.trim()) {
      alert('Please enter product category');
      return false;
    }
    if (!productForm.price || parseFloat(productForm.price) <= 0) {
      alert('Please enter a valid price');
      return false;
    }
    if (!productForm.img.trim()) {
      alert('Please enter product image URL or filename');
      return false;
    }
    return true;
  };

  const addProduct = async () => {
    if (!validateProductForm()) return;

    setLoading(true);
    try {
      const db = getDatabase();
      const productsRef = ref(db, 'MedicalProducts');
      const newProductRef = push(productsRef);

      const productData = {
        title: productForm.title.trim(),
        description: productForm.description.trim(),
        category: productForm.category.trim(),
        price: parseFloat(productForm.price).toFixed(2),
        oldPrice: productForm.oldPrice ? parseFloat(productForm.oldPrice).toFixed(2) : '',
        discount: productForm.discount || '',
        img: productForm.img.trim(),
        createdAt: new Date().toISOString()
      };

      await set(newProductRef, productData);
      alert('Product added successfully!');
      setShowProductForm(false);
      resetProductForm();
      await loadProducts();
    } catch (error) {
      console.error('Error adding product:', error);
      alert('Failed to add product');
    } finally {
      setLoading(false);
    }
  };

  const updateProduct = async () => {
    if (!validateProductForm() || !editingProduct) return;

    setLoading(true);
    try {
      const db = getDatabase();
      const productRef = ref(db, `MedicalProducts/${editingProduct.id}`);

      const productData = {
        title: productForm.title.trim(),
        description: productForm.description.trim(),
        category: productForm.category.trim(),
        price: parseFloat(productForm.price).toFixed(2),
        oldPrice: productForm.oldPrice ? parseFloat(productForm.oldPrice).toFixed(2) : null,
        discount: productForm.discount || null,
        img: productForm.img.trim(),
        createdAt: editingProduct.createdAt
      };

      await set(productRef, productData);
      alert('Product updated successfully!');
      setShowProductForm(false);
      resetProductForm();
      await loadProducts();
    } catch (error) {
      console.error('Error updating product:', error);
      alert('Failed to update product');
    } finally {
      setLoading(false);
    }
  };

  const deleteProduct = async (productId) => {
    if (!window.confirm('Are you sure you want to delete this product?')) {
      return;
    }

    setLoading(true);
    try {
      const db = getDatabase();
      const productRef = ref(db, `MedicalProducts/${productId}`);
      await set(productRef, null);
      alert('Product deleted successfully!');
      await loadProducts();
    } catch (error) {
      console.error('Error deleting product:', error);
      alert('Failed to delete product');
    } finally {
      setLoading(false);
    }
  };

  const editProduct = (product) => {
    setEditingProduct(product);
    setProductForm({
      title: product.title,
      description: product.description,
      category: product.category,
      price: product.price.toString(),
      oldPrice: product.oldPrice ? product.oldPrice.toString() : '',
      discount: product.discount || '',
      img: product.img
    });
    setShowProductForm(true);
  };

  const updateOrderStatus = async (orderId, newStatus) => {
    setLoading(true);
    try {
      await orderService.updateOrderStatus(orderId, newStatus);
      
      // Update the local state
      setOrders(prevOrders => 
        prevOrders.map(order => 
          order.id === orderId 
            ? { ...order, status: newStatus }
            : order
        )
      );
      
      alert('Order status updated successfully!');
    } catch (error) {
      console.error('Error updating order status:', error);
      alert('Failed to update order status');
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-SG', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'pending': return '#ffc107';
      case 'confirmed': return '#17a2b8';
      case 'shipped': return '#28a745';
      case 'delivered': return '#6c757d';
      default: return '#6c757d';
    }
  };

  return (
    <div className="admin-panel">
      <div className="admin-header">
        <h1>Manage products, orders, and view analytics</h1>
        <p></p>
      </div>

      <div className="admin-tabs">
        <button 
          className={`tab-btn ${activeTab === 'products' ? 'active' : ''}`}
          onClick={() => setActiveTab('products')}
        >
          📦 Products
        </button>
        <button 
          className={`tab-btn ${activeTab === 'orders' ? 'active' : ''}`}
          onClick={() => setActiveTab('orders')}
        >
          📋 Orders
        </button>
        <button 
          className={`tab-btn ${activeTab === 'analytics' ? 'active' : ''}`}
          onClick={() => setActiveTab('analytics')}
        >
          📊 Analytics
        </button>
      </div>

      <div className="admin-content">
        {loading && (
          <div className="loading-overlay">
            <div className="loading-spinner">Loading...</div>
          </div>
        )}

        {/* Products Tab */}
        {activeTab === 'products' && (
          <div className="products-section">
            <div className="section-header">
              <h2>Product Management</h2>
              <button 
                className="add-product-btn"
                onClick={() => {
                  resetProductForm();
                  setShowProductForm(true);
                }}
              >
                + Add New Product
              </button>
            </div>

            {showProductForm && (
              <div className="product-form-modal">
                <div className="modal-content">
                  <div className="modal-header">
                    <h3>{editingProduct ? 'Edit Product' : 'Add New Product'}</h3>
                    <button 
                      className="close-btn"
                      onClick={() => {
                        setShowProductForm(false);
                        resetProductForm();
                      }}
                    >
                      ✕
                    </button>
                  </div>
                  
                  <div className="form-grid">
                    <div className="form-group">
                      <label>Product Title *</label>
                      <input
                        type="text"
                        value={productForm.title}
                        onChange={(e) => handleProductInputChange('title', e.target.value)}
                        placeholder="Enter product title"
                      />
                    </div>

                    <div className="form-group">
                      <label>Category *</label>
                      <input
                        type="text"
                        value={productForm.category}
                        onChange={(e) => handleProductInputChange('category', e.target.value)}
                        placeholder="e.g., Pain Relief, Vitamins"
                      />
                    </div>

                    <div className="form-group full-width">
                      <label>Description *</label>
                      <textarea
                        value={productForm.description}
                        onChange={(e) => handleProductInputChange('description', e.target.value)}
                        placeholder="Enter product description"
                        rows="3"
                      />
                    </div>

                    <div className="form-group">
                      <label>Price (S$) *</label>
                      <input
                        type="number"
                        step="0.01"
                        value={productForm.price}
                        onChange={(e) => handleProductInputChange('price', e.target.value)}
                        placeholder="0.00"
                      />
                    </div>

                    <div className="form-group">
                      <label>Old Price (S$)</label>
                      <input
                        type="number"
                        step="0.01"
                        value={productForm.oldPrice}
                        onChange={(e) => handleProductInputChange('oldPrice', e.target.value)}
                        placeholder="0.00"
                      />
                    </div>

                    <div className="form-group">
                      <label>Discount</label>
                      <input
                        type="text"
                        value={productForm.discount}
                        onChange={(e) => handleProductInputChange('discount', e.target.value)}
                        placeholder="e.g., 20% OFF"
                      />
                    </div>

                    <div className="form-group full-width">
                      <label>Image URL or Filename *</label>
                      <input
                        type="text"
                        value={productForm.img}
                        onChange={(e) => handleProductInputChange('img', e.target.value)}
                        placeholder="https://example.com/image.jpg OR product-image.png"
                      />
                      <div className="image-input-help">
                        <small>
                          Enter either a full image URL or a filename from the medicineandproductimages folder
                        </small>
                      </div>
                      {imagePreview && (
                        <div className="image-preview">
                          <p>Preview:</p>
                          <img src={imagePreview} alt="Preview" onError={(e) => {
                            e.target.src = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5JbWFnZSBub3QgYXZhaWxhYmxlPC90ZXh0Pjwvc3ZnPg==";
                          }} />
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="form-actions">
                    <button 
                      className="cancel-btn"
                      onClick={() => {
                        setShowProductForm(false);
                        resetProductForm();
                      }}
                    >
                      Cancel
                    </button>
                    <button 
                      className="save-btn"
                      onClick={editingProduct ? updateProduct : addProduct}
                      disabled={loading}
                    >
                      {loading ? 'Saving...' : (editingProduct ? 'Update Product' : 'Add Product')}
                    </button>
                  </div>
                </div>
              </div>
            )}

            <div className="products-grid">
              {products.map(product => (
                <div key={product.id} className="product-card">
                  <div className="product-image">
                    <img 
                      src={product.displayImg} 
                      alt={product.title}
                      onError={(e) => {
                        e.target.src = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5JbWFnZSBub3QgYXZhaWxhYmxlPC90ZXh0Pjwvc3ZnPg==";
                      }}
                    />
                  </div>
                  <div className="product-info">
                    <h4 className="product-title">{product.title}</h4>
                    <p className="product-category">{product.category}</p>
                    <p className="product-price">
                      {product.price}
                      {product.oldPrice && (
                        <span className="old-price"> {product.oldPrice}</span>
                      )}
                    </p>
                    {product.discount && (
                      <span className="discount-badge">{product.discount}</span>
                    )}
                    <p className="product-description">{product.description}</p>
                  </div>
                  <div className="product-actions">
                    <button 
                      className="edit-btn"
                      onClick={() => editProduct(product)}
                    >
                      Edit
                    </button>
                    <button 
                      className="delete-btn"
                      onClick={() => deleteProduct(product.id)}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))}
            </div>

            {products.length === 0 && !loading && (
              <div className="empty-state">
                <p>No products found. Add your first product!</p>
              </div>
            )}
          </div>
        )}

        {/* Orders Tab */}
        {activeTab === 'orders' && (
          <div className="orders-section">
            <div className="section-header">
              <h2>Order Management</h2>
              <div className="orders-stats">
                <span>Total Orders: {orders.length}</span>
              </div>
            </div>

            <div className="orders-list">
              {orders.map(order => (
                <div key={order.id} className="order-card">
                  <div className="order-header">
                    <div className="order-info">
                      <h4>Order #{order.id.slice(-8)}</h4>
                      <p className="order-user">{order.userEmail}</p>
                      <p className="order-date">{formatDate(order.createdAt)}</p>
                    </div>
                    <div className="order-status-section">
                      <select 
                        value={order.status}
                        onChange={(e) => updateOrderStatus(order.id, e.target.value)}
                        className="status-select"
                        style={{ borderColor: getStatusColor(order.status) }}
                      >
                        <option value="pending">Pending</option>
                        <option value="confirmed">Confirmed</option>
                        <option value="shipped">Shipped</option>
                        <option value="delivered">Delivered</option>
                      </select>
                      <div 
                        className="status-badge"
                        style={{ backgroundColor: getStatusColor(order.status) }}
                      >
                        {order.status}
                      </div>
                    </div>
                  </div>

                  <div className="order-items">
                    <h5>Items:</h5>
                    {order.items.map(item => (
                      <div key={item.id} className="order-item">
                        <img 
                          src={item.displayImage} 
                          alt={item.name}
                          onError={(e) => {
                            e.target.src = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5JbWFnZSBub3QgYXZhaWxhYmxlPC90ZXh0Pjwvc3ZnPg==";
                          }}
                        />
                        <div className="item-details">
                          <span className="item-name">{item.name}</span>
                          <span className="item-quantity">Qty: {item.quantity}</span>
                          <span className="item-price">S${item.price}</span>
                        </div>
                      </div>
                    ))}
                  </div>

                  <div className="order-footer">
                    <div className="order-total">
                      <strong>Total: S${order.totalAmount}</strong>
                    </div>
                    <div className="order-address">
                      <strong>Delivery to:</strong>
                      <p>{order.deliveryAddress.recipientName}</p>
                      <p>{order.deliveryAddress.blockStreet}</p>
                      <p>{order.deliveryAddress.unitNumber}, Singapore {order.deliveryAddress.postalCode}</p>
                    </div>
                    <div className="order-payment">
                      <strong>Payment:</strong>
                      <p>
                        {order.paymentMethod.method === 'wallet' && 'Wallet'}
                        {order.paymentMethod.method === 'paynow' && 'PayNow'}
                        {order.paymentMethod.method === 'card' && 
                          `${order.paymentMethod.cardType} •••• ${order.paymentMethod.lastFour}`}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {orders.length === 0 && !loading && (
              <div className="empty-state">
                <p>No orders found.</p>
              </div>
            )}
          </div>
        )}

        {/* Analytics Tab */}
        {activeTab === 'analytics' && (
          <div className="analytics-section">
            <div className="section-header">
              <h2>Sales Analytics</h2>
            </div>

            <div className="stats-cards">
              <div className="stat-card">
                <div className="stat-icon">📦</div>
                <div className="stat-info">
                  <h3>{productStats.totalProducts || 0}</h3>
                  <p>Total Products</p>
                </div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">📋</div>
                <div className="stat-info">
                  <h3>{productStats.totalOrders || 0}</h3>
                  <p>Total Orders</p>
                </div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">💰</div>
                <div className="stat-info">
                  <h3>S${(productStats.totalRevenue || 0).toFixed(2)}</h3>
                  <p>Total Revenue</p>
                </div>
              </div>
            </div>

            <div className="analytics-grid">
              <div className="analytics-card">
                <h3>Most Popular Products</h3>
                {productStats.popularProducts && productStats.popularProducts.length > 0 ? (
                  <div className="popular-list">
                    {productStats.popularProducts.slice(0, 5).map((product, index) => (
                      <div key={product.id} className="popular-item">
                        <div className="rank">#{index + 1}</div>
                        <div className="product-details">
                          <span className="product-name">{product.name}</span>
                          <span className="product-stats">
                            {product.totalSold} sold • S${product.totalRevenue.toFixed(2)}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p>No sales data available</p>
                )}
              </div>

              <div className="analytics-card">
                <h3>Categories Performance</h3>
                {productStats.popularCategories && productStats.popularCategories.length > 0 ? (
                  <div className="categories-list">
                    {productStats.popularCategories.map((category, index) => (
                      <div key={category.name} className="category-item">
                        <div className="category-name">{category.name}</div>
                        <div className="category-stats">
                          <span>{category.totalSold} sold</span>
                          <span>S${category.totalRevenue.toFixed(2)}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p>No category data available</p>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default AdminMedicalProducts;
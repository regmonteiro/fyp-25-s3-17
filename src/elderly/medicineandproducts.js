import React, { useState, useEffect } from "react";
import "./medicineandproducts.css";
import { useNavigate } from "react-router-dom";
import { MedicalProductsController } from "../controller/medicalproductsController";
import { MedicalProductsEntity } from "../entity/medicalproductsEntity";
import { getDatabase, ref, get, set } from "firebase/database";

// Cart Service for Firebase operations (same as in Cart component)
class CartService {
  constructor(userEmail = null) {
    this.userEmail = userEmail;
    this.db = getDatabase();
  }

  // Get user's cart from Firebase
  async getCart() {
    try {
      if (!this.userEmail) return [];
      
      const cartRef = ref(this.db, `MedicalProducts/carts/${this.userEmail.replace(/[.#$\/\[\]]/g, '_')}`);
      const snapshot = await get(cartRef);
      
      if (!snapshot.exists()) {
        return [];
      }

      return snapshot.val().items || [];
    } catch (error) {
      console.error('Error fetching cart:', error);
      return [];
    }
  }

  // Save cart to Firebase
  async saveCart(cartItems) {
    try {
      if (!this.userEmail) return false;
      
      const cartRef = ref(this.db, `MedicalProducts/carts/${this.userEmail.replace(/[.#$\/\[\]]/g, '_')}`);
      await set(cartRef, {
        userEmail: this.userEmail,
        items: cartItems,
        lastUpdated: new Date().toISOString()
      });
      return true;
    } catch (error) {
      console.error('Error saving cart:', error);
      return false;
    }
  }

  // Clear cart from Firebase
  async clearCart() {
    try {
      if (!this.userEmail) return false;
      
      const cartRef = ref(this.db, `MedicalProducts/carts/${this.userEmail.replace(/[.#$\/\[\]]/g, '_')}`);
      await set(cartRef, null);
      return true;
    } catch (error) {
      console.error('Error clearing cart:', error);
      return false;
    }
  }
}

const getImagePath = (imageNameOrUrl) => {
  // If it's already a full URL (http/https), return as is
  if (imageNameOrUrl?.startsWith("http")) {
    return imageNameOrUrl;
  }

  // If it's a base64 image, return as is
  if (imageNameOrUrl?.startsWith("data:")) {
    return imageNameOrUrl;
  }

  // If it's a local image path, try to require it
  if (imageNameOrUrl) {
    try {
      return require(`../elderly/medicineandproductimages/${imageNameOrUrl}`);
    } catch (error) {
      console.log(`Local image not found: ${imageNameOrUrl}`);
    }
  }

  // Fallback placeholder image
  return "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5JbWFnZSBub3QgYXZhaWxhYmxlPC90ZXh0Pjwvc3ZnPg==";
};

export default function Shop() {
  const navigate = useNavigate();
  const [products, setProducts] = useState([]);
  const [cartCount, setCartCount] = useState(0);
  const [activeCategory, setActiveCategory] = useState("all");
  const [messages, setMessages] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [userEmail, setUserEmail] = useState('');
  const [cartService, setCartService] = useState(null);

  const productsController = new MedicalProductsController();

  // Initialize user and cart service
  useEffect(() => {
    const currentUserEmail = localStorage.getItem('userEmail') || 'demo@example.com';
    setUserEmail(currentUserEmail);
    
    const cartServiceInstance = new CartService(currentUserEmail);
    setCartService(cartServiceInstance);
    
    loadCartCount(cartServiceInstance);
    fetchProducts();
  }, []);

  // Fetch products from Firestore using controller
  const fetchProducts = async () => {
    try {
      setLoading(true);
      const result = await productsController.getAllProducts();

      if (result.success) {
        setProducts(result.data);
        setError(null);
      } else {
        setError(result.error);
      }
    } catch (err) {
      console.error("Error fetching products:", err);
      setError("Failed to load products. Please try again later.");
    } finally {
      setLoading(false);
    }
  };

  // Load cart count from Firebase
  const loadCartCount = async (cartServiceInstance = cartService) => {
    if (!cartServiceInstance) return;
    
    try {
      const cartItems = await cartServiceInstance.getCart();
      const count = cartItems.reduce((sum, item) => sum + item.quantity, 0);
      setCartCount(count);
    } catch (error) {
      console.error('Error loading cart count:', error);
      // Fallback to localStorage if Firebase fails
      const savedCart = localStorage.getItem("shoppingCart");
      if (savedCart) {
        const parsedCart = JSON.parse(savedCart);
        const count = parsedCart.reduce((sum, item) => sum + item.quantity, 0);
        setCartCount(count);
      }
    }
  };

  const addToCart = async (product) => {
    if (!cartService) {
      console.error('Cart service not initialized');
      return;
    }

    const productId = MedicalProductsEntity.generateProductId(product);

    // ✅ Always ensure price is numeric
    let productPrice = product.price;
    if (typeof productPrice === "string") {
      productPrice = parseFloat(productPrice.replace(/[^\d.]/g, ""));
    } else {
      productPrice = parseFloat(productPrice);
    }

    if (isNaN(productPrice)) {
      console.error("Invalid product price:", product.price);
      productPrice = 0; // fallback
    }

    try {
      // Get current cart from Firebase
      const existingCart = await cartService.getCart();

      // Check if item already exists in cart
      const existingItemIndex = existingCart.findIndex(
        (item) => item.id === productId
      );

      let updatedCart;
      if (existingItemIndex >= 0) {
        // Update quantity if item exists
        updatedCart = [...existingCart];
        updatedCart[existingItemIndex].quantity += 1;
      } else {
        // Add new item to cart
        const newItem = {
          id: productId,
          name: product.title,
          price: productPrice, // ✅ fixed numeric price
          image: getImagePath(product.img),
          quantity: 1,
          productData: product, // Store full product data for reference
        };
        updatedCart = [...existingCart, newItem];
      }

      // Save to Firebase
      const success = await cartService.saveCart(updatedCart);
      
      if (success) {
        // Update state
        const count = updatedCart.reduce((sum, item) => sum + item.quantity, 0);
        setCartCount(count);

        // Show success message
        setMessages({ ...messages, [product.id]: "Product is added to cart." });
        setTimeout(() => {
          setMessages((prev) => ({ ...prev, [product.id]: "" }));
        }, 3000);
      } else {
        throw new Error('Failed to save cart to Firebase');
      }
    } catch (error) {
      console.error('Error adding to cart:', error);
      
      // Fallback to localStorage if Firebase fails
      console.log('Falling back to localStorage...');
      const existingCart = JSON.parse(localStorage.getItem("shoppingCart")) || [];
      
      const existingItemIndex = existingCart.findIndex(
        (item) => item.id === productId
      );

      let updatedCart;
      if (existingItemIndex >= 0) {
        updatedCart = [...existingCart];
        updatedCart[existingItemIndex].quantity += 1;
      } else {
        const newItem = {
          id: productId,
          name: product.title,
          price: productPrice,
          image: getImagePath(product.img),
          quantity: 1,
          productData: product,
        };
        updatedCart = [...existingCart, newItem];
      }

      localStorage.setItem("shoppingCart", JSON.stringify(updatedCart));
      
      const count = updatedCart.reduce((sum, item) => sum + item.quantity, 0);
      setCartCount(count);

      setMessages({ ...messages, [product.id]: "Product is added to cart." });
      setTimeout(() => {
        setMessages((prev) => ({ ...prev, [product.id]: "" }));
      }, 3000);
    }
  };

  const openCart = () => {
    navigate("/elderly/cart");
  };

  const categories = [
    { key: "all", label: "Shop All" },
    { key: "mobility-safety", label: "Mobility and Safety" },
    { key: "health-and-wellness", label: "Health and Wellness" },
    { key: "pain-relief", label: "Pain Relief" },
    { key: "personal-care", label: "Personal Care" },
    { key: "monitoring-and-essentials", label: "Monitoring and Essentials" },
  ];

  const filteredProducts = products.filter(
    (p) => activeCategory === "all" || p.category === activeCategory
  );

  if (loading) {
    return (
      <div className="shop-container">
        <div className="loading">Loading products...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="shop-container">
        <div className="error-message">
          {error}
          <button onClick={fetchProducts} className="retry-button">
            Try Again
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="shop-container">
      <header>
        <h2>AllCare Shop</h2>
        <div
          className="cart-icon"
          onClick={openCart}
          style={{ cursor: "pointer" }}
        >
          🛒<span className="cart-count">{cartCount}</span>
        </div>
      </header>

      {/* Category Navigation */}
      <nav className="categories">
        {categories.map((cat) => (
          <button
            key={cat.key}
            onClick={() => setActiveCategory(cat.key)}
            className={`category-btn ${
              activeCategory === cat.key ? "active" : ""
            }`}
            data-category={cat.key}
          >
            {cat.label}
          </button>
        ))}
      </nav>

      {/* Product Grid */}
      <main>
        <div className="product-grid">
          {filteredProducts.map((product) => (
            <div
              key={product.id}
              className="product-card"
              data-category={product.category}
            >
              {product.discount && (
                <div className="discount">{product.discount}</div>
              )}
              <img
                src={getImagePath(product.img)}
                alt={product.title}
                onError={(e) => {
                  console.log(`Error loading image: ${product.img}`);
                  e.target.src =
                    "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5JbWFnZSBub3QgYXZhaWxhYmxlPC90ZXh0Pjwvc3ZnPg==";
                }}
              />
              <p className="title">{product.title}</p>
              <p className="description">{product.description}</p>
              <p className="price">
                {product.price}
                {product.oldPrice && (
                  <span className="old-price">{product.oldPrice}</span>
                )}
              </p>
              <p className="delivery">🚚 Same day delivery</p>
              <button
                className="add-to-cart"
                onClick={() => addToCart(product)}
              >
                Add to Cart
              </button>
              {messages[product.id] && (
                <div className="added-message">{messages[product.id]}</div>
              )}
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}
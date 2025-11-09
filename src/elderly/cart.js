// components/Cart.js
import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { getDatabase, ref, get, set, push } from "firebase/database";
import "./cart.css";
import { AddressService, WalletService } from "../entity/subscriptionEntity";
import { OrderService } from "../entity/orderServiceEntity";

// Cart Service for Firebase operations
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

// Payment Methods Service for Firebase
class PaymentMethodsService {
  constructor(userEmail = null) {
    this.userEmail = userEmail;
    this.db = getDatabase();
  }

  // Get saved payment methods from Firebase
  async getSavedCards() {
    try {
      if (!this.userEmail) return [];
      
      const cardsRef = ref(this.db, `MedicalProducts/paymentMethods/${this.userEmail.replace(/[.#$\/\[\]]/g, '_')}/cards`);
      const snapshot = await get(cardsRef);
      
      if (!snapshot.exists()) {
        return [];
      }

      const cardsData = snapshot.val();
      return Object.values(cardsData);
    } catch (error) {
      console.error('Error fetching saved cards:', error);
      return [];
    }
  }

  // Save payment method to Firebase
  async saveCard(cardData) {
    try {
      if (!this.userEmail) return null;
      
      const cardsRef = ref(this.db, `MedicalProducts/paymentMethods/${this.userEmail.replace(/[.#$\/\[\]]/g, '_')}/cards`);
      const newCardRef = push(cardsRef);
      
      const card = {
        id: newCardRef.key,
        ...cardData,
        createdAt: new Date().toISOString()
      };

      await set(newCardRef, card);
      return card;
    } catch (error) {
      console.error('Error saving card:', error);
      throw error;
    }
  }

  // Delete payment method from Firebase
  async deleteCard(cardId) {
    try {
      if (!this.userEmail) return false;
      
      const cardRef = ref(this.db, `MedicalProducts/paymentMethods/${this.userEmail.replace(/[.#$\/\[\]]/g, '_')}/cards/${cardId}`);
      await set(cardRef, null);
      return true;
    } catch (error) {
      console.error('Error deleting card:', error);
      throw error;
    }
  }
}

// Main Cart Component
const Cart = () => {
  const navigate = useNavigate();
  const [cart, setCart] = useState([]);
  const [showCheckoutModal, setShowCheckoutModal] = useState(false);
  const [selectedPaymentMethod, setSelectedPaymentMethod] = useState(null);
  const [selectedCardId, setSelectedCardId] = useState(null);
  const [selectedAddressId, setSelectedAddressId] = useState(null);
  const [showCardForm, setShowCardForm] = useState(false);
  const [showAddressForm, setShowAddressForm] = useState(false);
  const [savedCards, setSavedCards] = useState([]);
  const [savedAddresses, setSavedAddresses] = useState([]);
  const [walletBalance, setWalletBalance] = useState(0);
  const [userEmail, setUserEmail] = useState('');
  const [walletService, setWalletService] = useState(null);
  const [addressService, setAddressService] = useState(null);
  const [orderService, setOrderService] = useState(null);
  const [cartService, setCartService] = useState(null);
  const [paymentMethodsService, setPaymentMethodsService] = useState(null);
  const [orderHistory, setOrderHistory] = useState([]);
  const [showOrderHistory, setShowOrderHistory] = useState(false);
  
  // Form states
  const [cardForm, setCardForm] = useState({
    cardNumber: '',
    cardHolder: '',
    expiryDate: '',
    cvv: '',
    saveCard: false
  });
  
  const [addressForm, setAddressForm] = useState({
    addressName: '',
    recipientName: '',
    phoneNumber: '',
    blockStreet: '',
    unitNumber: '',
    postalCode: '',
    saveAddress: true,
    isDefault: false
  });

  // Load data and initialize services
  useEffect(() => {
    initializeServices();
  }, []);

  const initializeServices = async () => {
    // Get user email from your auth system
    const currentUserEmail = localStorage.getItem('userEmail') || 'demo@example.com';
    setUserEmail(currentUserEmail);
    
    // Initialize cart service
    const cartServiceInstance = new CartService(currentUserEmail);
    setCartService(cartServiceInstance);
    
    // Initialize payment methods service
    const paymentMethodsServiceInstance = new PaymentMethodsService(currentUserEmail);
    setPaymentMethodsService(paymentMethodsServiceInstance);
    
    // Load cart from Firebase
    const cartItems = await cartServiceInstance.getCart();
    setCart(cartItems);
    
    // Load saved cards from Firebase
    const cards = await paymentMethodsServiceInstance.getSavedCards();
    setSavedCards(cards);
    
    // Initialize wallet service
    const walletServiceInstance = new WalletService(currentUserEmail);
    await walletServiceInstance.initialize();
    setWalletService(walletServiceInstance);
    
    const balance = await walletServiceInstance.getWalletBalance();
    setWalletBalance(balance);
    
    // Initialize address service
    const addressServiceInstance = new AddressService(currentUserEmail);
    setAddressService(addressServiceInstance);
    
    // Initialize order service
    const orderServiceInstance = new OrderService(currentUserEmail);
    setOrderService(orderServiceInstance);
    
    // Load addresses from Firebase
    await loadAddresses(addressServiceInstance);
  };

  const loadAddresses = async (addressServiceInstance) => {
    if (!addressServiceInstance) return;
    
    try {
      const addresses = await addressServiceInstance.getAddresses();
      setSavedAddresses(addresses);
      
      if (addresses.length > 0 && !selectedAddressId) {
        const defaultAddress = addresses.find(addr => addr.isDefault) || addresses[0];
        if (defaultAddress) {
          setSelectedAddressId(defaultAddress.id);
        }
      }
    } catch (error) {
      console.error('Error loading addresses:', error);
    }
  };

  const loadOrderHistory = async () => {
    if (!orderService) return;
    
    try {
      const orders = await orderService.getUserOrders();
      setOrderHistory(orders);
    } catch (error) {
      console.error('Error loading order history:', error);
    }
  };

  const removeItem = async (productId) => {
    const updatedCart = cart.filter(item => {
      if (item.id === productId) {
        if (item.quantity > 1) {
          item.quantity -= 1;
          return true;
        }
        return false;
      }
      return true;
    });

    setCart(updatedCart);
    
    // Save to Firebase instead of localStorage
    if (cartService) {
      await cartService.saveCart(updatedCart);
    }
  };

  const calculateTotal = () => {
    return cart.reduce((sum, item) => sum + (parseFloat(item.price) * item.quantity), 0).toFixed(2);
  };

  const selectPaymentMethod = (method) => {
    setSelectedPaymentMethod(method);
    if (method !== 'card') {
      setSelectedCardId(null);
    }
  };

  const selectCard = (cardId) => {
    setSelectedCardId(cardId);
  };

  const selectAddress = (addressId) => {
    setSelectedAddressId(addressId);
  };

  const handleCardInputChange = (field, value) => {
    let formattedValue = value;
    
    if (field === 'cardNumber') {
      formattedValue = value.replace(/\s/g, '');
      if (formattedValue.length > 0) {
        formattedValue = formattedValue.match(/.{1,4}/g)?.join(' ') || formattedValue;
      }
    } else if (field === 'expiryDate') {
      formattedValue = value.replace(/\D/g, '');
      if (formattedValue.length >= 2) {
        formattedValue = formattedValue.slice(0, 2) + '/' + formattedValue.slice(2);
      }
    }
    
    setCardForm(prev => ({ ...prev, [field]: formattedValue }));
  };

  const handleAddressInputChange = (field, value) => {
    setAddressForm(prev => ({ ...prev, [field]: value }));
  };

  const getCardType = (cardNumber) => {
    const cleanNumber = cardNumber.replace(/\s/g, '');
    if (/^4/.test(cleanNumber)) return 'Visa';
    if (/^5[1-5]/.test(cleanNumber)) return 'Mastercard';
    if (/^3[47]/.test(cleanNumber)) return 'American Express';
    return 'Credit Card';
  };

  const addNewCard = async () => {
    const { cardNumber, cardHolder, expiryDate, cvv, saveCard } = cardForm;
    const cleanCardNumber = cardNumber.replace(/\s/g, '');

    // Validation
    if (!cleanCardNumber || !cardHolder || !expiryDate || !cvv) {
      alert('Please fill in all card details');
      return;
    }

    if (cleanCardNumber.length !== 16) {
      alert('Please enter a valid 16-digit card number');
      return;
    }

    if (!/^\d{2}\/\d{2}$/.test(expiryDate)) {
      alert('Please enter a valid expiry date in MM/YY format');
      return;
    }

    if (!/^\d{3,4}$/.test(cvv)) {
      alert('Please enter a valid CVV (3 or 4 digits)');
      return;
    }

    const cardType = getCardType(cleanCardNumber);
    const lastFour = cleanCardNumber.slice(-4);

    const cardData = {
      cardType,
      lastFour,
      expiryDate,
      cardHolder,
      fullNumber: cleanCardNumber // Note: In production, never store full card numbers
    };

    try {
      if (saveCard && paymentMethodsService) {
        const newCard = await paymentMethodsService.saveCard(cardData);
        const updatedCards = [...savedCards, newCard];
        setSavedCards(updatedCards);
        setSelectedCardId(newCard.id);
        alert('Card saved successfully!');
      } else {
        // For one-time use, just add to local state without saving to Firebase
        const tempCard = {
          id: 'temp-' + Date.now(),
          ...cardData
        };
        setSelectedCardId(tempCard.id);
        alert('Card added for this payment only (not saved)');
      }

      setShowCardForm(false);
      setCardForm({
        cardNumber: '',
        cardHolder: '',
        expiryDate: '',
        cvv: '',
        saveCard: false
      });
    } catch (error) {
      console.error('Error saving card:', error);
      alert('Failed to save card. Please try again.');
    }
  };

  const deleteCard = async (cardId) => {
    if (!window.confirm('Are you sure you want to delete this card?')) {
      return;
    }

    try {
      if (paymentMethodsService) {
        await paymentMethodsService.deleteCard(cardId);
        const updatedCards = savedCards.filter(card => card.id !== cardId);
        setSavedCards(updatedCards);

        if (selectedCardId === cardId) {
          setSelectedCardId(null);
        }
        alert('Card deleted successfully');
      }
    } catch (error) {
      console.error('Error deleting card:', error);
      alert('Failed to delete card. Please try again.');
    }
  };

  const addNewAddress = async () => {
    const { addressName, recipientName, phoneNumber, blockStreet, unitNumber, postalCode, saveAddress, isDefault } = addressForm;

    // Validation
    if (!addressName || !recipientName || !phoneNumber || !blockStreet || !unitNumber || !postalCode) {
      alert('Please fill in all address details');
      return;
    }

    if (postalCode.length !== 6 || !/^\d+$/.test(postalCode)) {
      alert('Please enter a valid 6-digit postal code');
      return;
    }

    // Flexible Singapore phone number validation
    const cleanPhoneNumber = phoneNumber.replace(/\s/g, '').replace(/[-\+\(\)]/g, '');
    const singaporePhoneRegex = /^(?:\+?65)?[689]\d{7}$/;

    if (!singaporePhoneRegex.test(cleanPhoneNumber)) {
      alert('Please enter a valid Singapore phone number (8 digits starting with 6, 8, or 9)');
      return;
    }

    if (!addressService) {
      alert('Address service not initialized');
      return;
    }

    try {
      const addressData = {
        name: addressName,
        recipientName,
        phoneNumber: cleanPhoneNumber, // Store cleaned number
        blockStreet,
        unitNumber,
        postalCode,
        isDefault: isDefault || savedAddresses.length === 0
      };

      const newAddress = await addressService.saveAddress(addressData);
      
      // If this address is set as default, update all other addresses
      if (addressData.isDefault) {
        await addressService.setDefaultAddress(newAddress.id);
      }

      // Reload addresses to get updated list
      await loadAddresses(addressService);
      
      setSelectedAddressId(newAddress.id);
      setShowAddressForm(false);
      setAddressForm({
        addressName: '',
        recipientName: '',
        phoneNumber: '',
        blockStreet: '',
        unitNumber: '',
        postalCode: '',
        saveAddress: true,
        isDefault: false
      });
      
      alert('Address saved successfully!');
    } catch (error) {
      console.error('Error saving address:', error);
      alert('Failed to save address. Please try again.');
    }
  };

  const deleteAddress = async (addressId) => {
    if (!window.confirm('Are you sure you want to delete this address?')) {
      return;
    }

    if (!addressService) {
      alert('Address service not initialized');
      return;
    }

    try {
      await addressService.deleteAddress(addressId);
      
      // Reload addresses
      await loadAddresses(addressService);
      
      if (selectedAddressId === addressId) {
        setSelectedAddressId(null);
      }
      
      alert('Address deleted successfully');
    } catch (error) {
      console.error('Error deleting address:', error);
      alert('Failed to delete address. Please try again.');
    }
  };

  const setDefaultAddress = async (addressId) => {
    if (!addressService) return;

    try {
      await addressService.setDefaultAddress(addressId);
      // Reload addresses to get updated list
      await loadAddresses(addressService);
    } catch (error) {
      console.error('Error setting default address:', error);
      alert('Failed to set default address. Please try again.');
    }
  };

  const canCompletePayment = () => {
    if (!selectedPaymentMethod || !selectedAddressId) return false;
    
    if (selectedPaymentMethod === 'card' && !selectedCardId) return false;
    if (selectedPaymentMethod === 'wallet') {
      const total = parseFloat(calculateTotal());
      return walletService?.hasSufficientBalance(total) || false;
    }
    
    return true;
  };

  const completePayment = async () => {
    if (!canCompletePayment()) {
      alert('Please complete all required fields');
      return;
    }

    const total = parseFloat(calculateTotal());
    const selectedAddress = savedAddresses.find(addr => addr.id === selectedAddressId);
    
    if (!selectedAddress) {
      alert('Selected address not found');
      return;
    }

    try {
      let paymentMessage = '';
      let paymentMethodDetails = {};
      
      if (selectedPaymentMethod === 'wallet') {
        // Process wallet payment
        const success = await walletService.makePayment(total, 'AllCare Shop Purchase');
        
        if (!success) {
          alert('Wallet payment failed. Please try another payment method.');
          return;
        }
        
        paymentMessage = `Wallet payment successful! Amount: S$${total}`;
        paymentMethodDetails = {
          method: 'wallet',
          amount: total
        };
        
        // Update wallet balance display
        const newBalance = await walletService.getWalletBalance();
        setWalletBalance(newBalance);
        
      } else if (selectedPaymentMethod === 'paynow') {
        paymentMessage = `PayNow payment successful! Amount: S$${total}`;
        paymentMethodDetails = {
          method: 'paynow',
          amount: total
        };
      } else {
        const selectedCard = savedCards.find(card => card.id === selectedCardId);
        paymentMessage = `Payment successful! Amount: S$${total}\nCharged to ${selectedCard.cardType} •••• ${selectedCard.lastFour}`;
        paymentMethodDetails = {
          method: 'card',
          cardType: selectedCard.cardType,
          lastFour: selectedCard.lastFour,
          amount: total
        };
      }

      // Create order record in Firebase
      if (orderService) {
        const orderData = {
          items: [...cart],
          totalAmount: total,
          paymentMethod: paymentMethodDetails,
          deliveryAddress: selectedAddress,
          status: 'confirmed',
          createdAt: new Date().toISOString()
        };

        const savedOrder = await orderService.createOrder(orderData);
        console.log('Order saved to database successfully:', savedOrder.id);
      } else {
        console.error('Order service not available');
      }

      const deliveryMessage = `\n\nDelivery to:\n${selectedAddress.recipientName}\n${selectedAddress.blockStreet}\n${selectedAddress.unitNumber}, Singapore ${selectedAddress.postalCode}\n${selectedAddress.phoneNumber}`;

      alert(paymentMessage + deliveryMessage);

      // Clear cart from Firebase
      setCart([]);
      if (cartService) {
        await cartService.clearCart();
      }

      setShowCheckoutModal(false);
      
      // Navigate back to shop
      navigate('/elderly/medicationAndDoctorPage');
      
    } catch (error) {
      console.error('Payment error:', error);
      alert(`Payment failed: ${error.message}`);
    }
  };

  const goBackToShop = () => {
    navigate('/elderly/medicationAndDoctorPage');
  };

  const toggleOrderHistory = async () => {
    if (!showOrderHistory) {
      await loadOrderHistory();
    }
    setShowOrderHistory(!showOrderHistory);
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-SG', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  if (cart.length === 0) {
    return (
      <div className="cart-container">
        <div className="cart-header">
          <h1>Shopping Cart</h1>
          <button className="close-btn" onClick={goBackToShop}>✕</button>
        </div>
        
        {/* Order History Toggle */}
        <div className="order-history-toggle">
          <button 
            className="view-order-history-btn"
            onClick={toggleOrderHistory}
          >
            {showOrderHistory ? 'Hide Order History' : 'View Order History'}
          </button>
        </div>

        {showOrderHistory ? (
          <div className="order-history-section">
            <h2>Order History</h2>
            {orderHistory.length === 0 ? (
              <div className="empty-order-history">
                <p>No orders found.</p>
                <p>Start shopping to see your order history here!</p>
              </div>
            ) : (
              <div className="order-history-list">
                {orderHistory.map(order => (
                  <div key={order.id} className="order-history-item">
                    <div className="order-header">
                      <div className="order-info">
                        <h3>Order #{order.id?.slice(-8) || 'N/A'}</h3>
                        <p className="order-date">{formatDate(order.createdAt)}</p>
                      </div>
                      <div className="order-status">
                        <span className={`status-badge status-${order.status}`}>
                          {order.status}
                        </span>
                        <p className="order-total">S${order.totalAmount}</p>
                      </div>
                    </div>
                    
                    <div className="order-items">
                      {order.items && order.items.map(item => (
                        <div key={item.id} className="order-item">
                          <img src={item.image} alt={item.name} className="order-item-image" />
                          <div className="order-item-details">
                            <p className="order-item-name">{item.name}</p>
                            <p className="order-item-price">S${item.price} x {item.quantity}</p>
                          </div>
                        </div>
                      ))}
                    </div>
                    
                    <div className="order-footer">
                      <div className="delivery-address">
                        <strong>Delivery to:</strong>
                        <p>{order.deliveryAddress?.recipientName}</p>
                        <p>{order.deliveryAddress?.blockStreet}</p>
                        <p>{order.deliveryAddress?.unitNumber}, Singapore {order.deliveryAddress?.postalCode}</p>
                      </div>
                      <div className="payment-method">
                        <strong>Payment:</strong>
                        <p>
                          {order.paymentMethod?.method === 'wallet' && 'Wallet'}
                          {order.paymentMethod?.method === 'paynow' && 'PayNow'}
                          {order.paymentMethod?.method === 'card' && 
                            `${order.paymentMethod.cardType} •••• ${order.paymentMethod.lastFour}`}
                        </p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : (
          <div className="cart-items">
            <div className="empty-cart-message">Your cart is empty.</div>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="cart-container">
      <div className="cart-header">
        <h1>Shopping Cart</h1>
        <button className="close-btn" onClick={goBackToShop}>✕</button>
      </div>
      
      {/* Wallet Balance Display */}
      <div className="wallet-balance-section">
        <div className="wallet-balance">
          <span className="wallet-icon">💰</span>
          <span className="wallet-text">Wallet Balance: </span>
          <span className="wallet-amount">S${walletBalance.toFixed(2)}</span>
        </div>
      </div>
      
      <div className="cart-items">
        {cart.map(item => (
          <div key={item.id} className="cart-item" data-id={item.id}>
            <img src={item.image} alt={item.name} className="cart-item-image" />
            <div className="cart-item-details">
              <p className="cart-item-name">{item.name}</p>
              <p className="cart-item-price">S${item.price} x {item.quantity}</p>
            </div>
            <button className="cart-item-remove" onClick={() => removeItem(item.id)}>
              Remove
            </button>
          </div>
        ))}
      </div>
      
      <div className="cart-footer">
        <div className="cart-total">
          Total: S$<span id="cart-total">{calculateTotal()}</span>
        </div>
        <button 
          className="checkout-btn" 
          onClick={() => setShowCheckoutModal(true)}
        >
          Proceed to Checkout
        </button>
      </div>

      {showCheckoutModal && (
        <div className="checkout-modal">
          <div className="checkout-modal-content">
            <button className="close-modal-btn" onClick={() => setShowCheckoutModal(false)}>✕</button>
            
            <div className="checkout-header">
              <h1>Checkout</h1>
              <p>Total Amount: S$<span id="checkout-total">{calculateTotal()}</span></p>
              {/* Show wallet balance in checkout modal too */}
              <div className="checkout-wallet-balance">
                Available Wallet Balance: S${walletBalance.toFixed(2)}
                {selectedPaymentMethod === 'wallet' && parseFloat(calculateTotal()) > walletBalance && (
                  <span className="insufficient-balance-warning">
                    ⚠️ Insufficient balance
                  </span>
                )}
              </div>
            </div>

            {/* Address Section */}
            <div className="address-section">
              <h3>Delivery Address</h3>
              
              <div id="saved-addresses-section">
                <div id="saved-addresses-list">
                  {savedAddresses.length === 0 ? (
                    <p>No saved addresses. Please add a delivery address.</p>
                  ) : (
                    savedAddresses.map(address => (
                      <div 
                        key={address.id}
                        className={`saved-address ${selectedAddressId === address.id ? 'selected' : ''}`}
                        onClick={() => selectAddress(address.id)}
                      >
                        <div className="saved-address-info">
                          <div className="saved-address-name">
                            <strong>{address.name}</strong>
                            {address.isDefault && <span className="default-address-badge">Default</span>}
                          </div>
                          <div className="saved-address-details">
                            <div><strong>{address.recipientName}</strong> • {address.phoneNumber}</div>
                            <div>{address.blockStreet}</div>
                            <div>{address.unitNumber} • Singapore {address.postalCode}</div>
                          </div>
                        </div>
                        <div className="address-actions">
                          {!address.isDefault && (
                            <button 
                              className="set-default-btn"
                              onClick={(e) => {
                                e.stopPropagation();
                                setDefaultAddress(address.id);
                              }}
                              title="Set as default"
                            >
                              ⭐
                            </button>
                          )}
                          <button 
                            className="delete-address-btn" 
                            onClick={(e) => {
                              e.stopPropagation();
                              deleteAddress(address.id);
                            }}
                          >
                            ×
                          </button>
                        </div>
                      </div>
                    ))
                  )}
                </div>
                
                <button className="add-address-btn" onClick={() => setShowAddressForm(true)}>
                  + Add New Address
                </button>

                {showAddressForm && (
                  <div className="address-form">
                    <h4>Add New Address</h4>
                    <div className="form-group">
                      <label htmlFor="address-name">Address Name (e.g., Home, Office)</label>
                      <input 
                        type="text" 
                        id="address-name" 
                        placeholder="Home" 
                        maxLength="50"
                        value={addressForm.addressName}
                        onChange={(e) => handleAddressInputChange('addressName', e.target.value)}
                      />
                    </div>
                    <div className="form-group">
                      <label htmlFor="recipient-name">Recipient Name</label>
                      <input 
                        type="text" 
                        id="recipient-name" 
                        placeholder="John Doe"
                        value={addressForm.recipientName}
                        onChange={(e) => handleAddressInputChange('recipientName', e.target.value)}
                      />
                    </div>
                    <div className="form-group">
                      <label htmlFor="phone-number">Phone Number</label>
                      <input 
                        type="text" 
                        id="phone-number" 
                        placeholder="+65 1234 5678" 
                        maxLength="15"
                        value={addressForm.phoneNumber}
                        onChange={(e) => handleAddressInputChange('phoneNumber', e.target.value)}
                      />
                    </div>
                    <div className="form-group">
                      <label htmlFor="block-street">Block & Street Name</label>
                      <input 
                        type="text" 
                        id="block-street" 
                        placeholder="123 Main Street"
                        value={addressForm.blockStreet}
                        onChange={(e) => handleAddressInputChange('blockStreet', e.target.value)}
                      />
                    </div>
                    <div className="form-row">
                      <div className="form-group">
                        <label htmlFor="unit-number">Unit Number</label>
                        <input 
                          type="text" 
                          id="unit-number" 
                          placeholder="#01-01"
                          value={addressForm.unitNumber}
                          onChange={(e) => handleAddressInputChange('unitNumber', e.target.value)}
                        />
                      </div>
                      <div className="form-group">
                        <label htmlFor="postal-code">Postal Code</label>
                        <input 
                          type="text" 
                          id="postal-code" 
                          placeholder="123456" 
                          maxLength="6"
                          value={addressForm.postalCode}
                          onChange={(e) => handleAddressInputChange('postalCode', e.target.value)}
                        />
                      </div>
                    </div>
                    <div className="checkbox-container">
                      <input 
                        type="checkbox" 
                        id="set-default-address"
                        checked={addressForm.isDefault}
                        onChange={(e) => handleAddressInputChange('isDefault', e.target.checked)}
                      />
                      <label htmlFor="set-default-address">
                        Set as default address
                      </label>
                    </div>
                    <div className="form-row">
                      <button onClick={addNewAddress} className="complete-payment-btn">Save Address</button>
                      <button 
                        onClick={() => setShowAddressForm(false)} 
                        className="cancel-btn"
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Payment Options - TABLE LAYOUT */}
            <div className="payment-section">
              <h3>Select Payment Method</h3>
              
              <table className="payment-table">
                <tbody>
                  <tr 
                    className={`payment-row ${selectedPaymentMethod === 'wallet' ? 'selected' : ''}`}
                    onClick={() => selectPaymentMethod('wallet')} 
                  >
                    <td className="radio-cell">
                      <input 
                        type="radio" 
                        name="payment" 
                        value="wallet"
                        checked={selectedPaymentMethod === 'wallet'}
                        readOnly
                      />
                    </td>
                    <td className="icon-cell">
                      <span className="payment-icon">💰</span>
                    </td>
                    <td className="label-cell">
                      Wallet Balance
                      <div className="payment-subtext">
                        Available: S${walletBalance.toFixed(2)}
                      </div>
                    </td>
                  </tr>
                  
                  <tr 
                    className={`payment-row ${selectedPaymentMethod === 'paynow' ? 'selected' : ''}`}
                    onClick={() => selectPaymentMethod('paynow')}
                  >
                    <td className="radio-cell">
                      <input 
                        type="radio" 
                        name="payment" 
                        value="paynow"
                        checked={selectedPaymentMethod === 'paynow'}
                        readOnly
                      />
                    </td>
                    <td className="icon-cell">
                      <span className="payment-icon">📱</span>
                    </td>
                    <td className="label-cell">
                      PayNow
                    </td>
                  </tr>
                  
                  <tr 
                    className={`payment-row ${selectedPaymentMethod === 'card' ? 'selected' : ''}`}
                    onClick={() => selectPaymentMethod('card')}
                  >
                    <td className="radio-cell">
                      <input 
                        type="radio" 
                        name="payment" 
                        value="card"
                        checked={selectedPaymentMethod === 'card'}
                        readOnly
                      />
                    </td>
                    <td className="icon-cell">
                      <span className="payment-icon">💳</span>
                    </td>
                    <td className="label-cell">
                      Bank Card
                    </td>
                  </tr>
                </tbody>
              </table>

              {/* Saved Cards Section */}
              {selectedPaymentMethod === 'card' && (
                <div className="saved-cards-section">
                  <h4>Saved Cards</h4>
                  
                  {savedCards.length === 0 ? (
                    <p className="no-cards-message">No saved cards. Add a new card to proceed.</p>
                  ) : (
                    <table className="saved-cards-table">
                      <tbody>
                        {savedCards.map(card => (
                          <tr 
                            key={card.id}
                            className={`saved-card-row ${selectedCardId === card.id ? 'selected' : ''}`}
                            onClick={() => selectCard(card.id)}
                          >
                            <td className="radio-cell">
                              <input 
                                type="radio" 
                                name="saved-card" 
                                checked={selectedCardId === card.id}
                                readOnly
                              />
                            </td>
                            <td className="icon-cell">
                              <span className="payment-icon">💳</span>
                            </td>
                            <td className="card-info-cell">
                              <div className="card-info">
                                <strong>{card.cardType} •••• {card.lastFour}</strong>
                              </div>
                            </td>
                            <td className="action-cell">
                              <button 
                                className="delete-card-btn" 
                                onClick={(e) => {
                                  e.stopPropagation();
                                  deleteCard(card.id);
                                }}
                              >
                                ×
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                  
                  <button className="add-card-btn" onClick={() => setShowCardForm(true)}>
                    + Add New Card
                  </button>

                  {showCardForm && (
                    <div className="card-form">
                      <h4>Add New Card</h4>
                      <div className="form-group">
                        <label htmlFor="card-number">Card Number</label>
                        <input 
                          type="text" 
                          id="card-number" 
                          placeholder="1234 5678 9012 3456" 
                          maxLength="19"
                          value={cardForm.cardNumber}
                          onChange={(e) => handleCardInputChange('cardNumber', e.target.value)}
                        />
                      </div>
                      <div className="form-group">
                        <label htmlFor="card-holder">Cardholder Name</label>
                        <input 
                          type="text" 
                          id="card-holder" 
                          placeholder="John Doe"
                          value={cardForm.cardHolder}
                          onChange={(e) => handleCardInputChange('cardHolder', e.target.value)}
                        />
                      </div>
                      <div className="form-row">
                        <div className="form-group">
                          <label htmlFor="expiry-date">Expiry Date</label>
                          <input 
                            type="text" 
                            id="expiry-date" 
                            placeholder="MM/YY" 
                            maxLength="5"
                            value={cardForm.expiryDate}
                            onChange={(e) => handleCardInputChange('expiryDate', e.target.value)}
                          />
                        </div>
                        <div className="form-group">
                          <label htmlFor="cvv">CVV</label>
                          <input 
                            type="text" 
                            id="cvv" 
                            placeholder="123" 
                            maxLength="3"
                            value={cardForm.cvv}
                            onChange={(e) => handleCardInputChange('cvv', e.target.value)}
                          />
                        </div>
                      </div>
                      <div className="checkbox-container">
                        <input 
                          type="checkbox" 
                          id="save-card"
                          checked={cardForm.saveCard}
                          onChange={(e) => handleCardInputChange('saveCard', e.target.checked)}
                        />
                        <label htmlFor="save-card">
                          Save this card for future payments
                        </label>
                      </div>
                      <div className="form-row">
                        <button onClick={addNewCard} className="complete-payment-btn">Add Card</button>
                        <button 
                          onClick={() => setShowCardForm(false)}
                          className="cancel-btn"
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>

            <button 
              id="complete-payment" 
              className="complete-payment-btn" 
              onClick={completePayment}
              disabled={!canCompletePayment()}
            >
              Complete Payment
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default Cart;
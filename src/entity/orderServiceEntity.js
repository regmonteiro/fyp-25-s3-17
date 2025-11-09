// entity/orderServiceEntity.js
import { getDatabase, ref, push, set, get, query, orderByChild, equalTo } from "firebase/database";

export class OrderService {
  constructor(userEmail = null) {
    this.userEmail = userEmail;
    this.db = getDatabase();
  }

  // Create a new order
  async createOrder(orderData) {
    try {
      const ordersRef = ref(this.db, 'MedicalProducts/orders');
      const newOrderRef = push(ordersRef);
      
      const order = {
        id: newOrderRef.key,
        userEmail: this.userEmail,
        items: orderData.items,
        totalAmount: orderData.totalAmount,
        paymentMethod: orderData.paymentMethod,
        deliveryAddress: orderData.deliveryAddress,
        status: orderData.status || 'confirmed',
        createdAt: new Date().toISOString(),
        timestamp: Date.now() // For sorting
      };

      await set(newOrderRef, order);
      console.log('Order created successfully:', order.id);
      return order;
    } catch (error) {
      console.error('Error creating order:', error);
      throw new Error('Failed to create order: ' + error.message);
    }
  }

  // Get all orders for the current user
  async getUserOrders() {
    try {
      const ordersRef = ref(this.db, 'MedicalProducts/orders');
      const snapshot = await get(ordersRef);
      
      if (!snapshot.exists()) {
        return [];
      }

      const orders = [];
      snapshot.forEach((childSnapshot) => {
        const order = childSnapshot.val();
        // Return only orders for the current user
        if (order.userEmail === this.userEmail) {
          orders.push(order);
        }
      });

      // Sort by timestamp, newest first
      return orders.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
    } catch (error) {
      console.error('Error fetching user orders:', error);
      throw new Error('Failed to fetch orders: ' + error.message);
    }
  }

  // Get ALL orders (for admin) - FIXED to work without user email filtering
  async getAllOrders() {
    try {
      const ordersRef = ref(this.db, 'MedicalProducts/orders');
      const snapshot = await get(ordersRef);
      
      if (!snapshot.exists()) {
        return [];
      }

      const orders = [];
      snapshot.forEach((childSnapshot) => {
        const order = childSnapshot.val();
        orders.push(order);
      });

      // Sort by timestamp, newest first
      return orders.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
    } catch (error) {
      console.error('Error fetching all orders:', error);
      throw error;
    }
  }

  // Get order by ID
  async getOrderById(orderId) {
    try {
      const orderRef = ref(this.db, `MedicalProducts/orders/${orderId}`);
      const snapshot = await get(orderRef);
      
      if (snapshot.exists()) {
        return snapshot.val();
      }
      return null;
    } catch (error) {
      console.error('Error fetching order:', error);
      throw error;
    }
  }

  // Update order status
  async updateOrderStatus(orderId, status) {
    try {
      const orderRef = ref(this.db, `MedicalProducts/orders/${orderId}/status`);
      await set(orderRef, status);
      return true;
    } catch (error) {
      console.error('Error updating order status:', error);
      throw error;
    }
  }

  // Get orders by status
  async getOrdersByStatus(status) {
    try {
      const ordersRef = ref(this.db, 'MedicalProducts/orders');
      const statusQuery = query(ordersRef, orderByChild('status'), equalTo(status));
      const snapshot = await get(statusQuery);
      
      if (!snapshot.exists()) {
        return [];
      }

      const orders = [];
      snapshot.forEach((childSnapshot) => {
        orders.push(childSnapshot.val());
      });

      return orders.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
    } catch (error) {
      console.error('Error fetching orders by status:', error);
      throw error;
    }
  }
}
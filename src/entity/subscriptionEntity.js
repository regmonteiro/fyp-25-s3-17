import { getDatabase, ref, get, set, push } from "firebase/database";
// Subscription Entity Class
class Subscription {
  constructor(data = {}) {
    this.id = data.id || '';
    this.active = data.active || false;
    this.autoPayment = data.autoPayment || false;
    this.nextPaymentDate = data.nextPaymentDate || '';
    this.paymentMethod = data.paymentMethod || '';
    this.paymentFailed = data.paymentFailed || false;
    this.cardName = data.cardName || '';
    this.cardNumber = data.cardNumber || '';
    this.expiryDate = data.expiryDate || '';
    this.cvv = data.cvv || '';
    this.walletBalance = data.walletBalance || 0;
    this.topUpHistory = data.topUpHistory || [];
    this.paymentHistory = data.paymentHistory || [];
    this.subscriptionPlan = data.subscriptionPlan || 0;
    this.startDate = data.startDate || '';
  }

  addToWallet(amount, paymentMethod, cardDetails = {}) {
    const previousBalance = this.walletBalance;
    this.walletBalance += amount;
    
    this.topUpHistory.unshift({
      amount: amount,
      cardDetails: cardDetails,
      id: `topup_${Date.now()}`,
      newBalance: this.walletBalance,
      paymentMethod: paymentMethod,
      previousBalance: previousBalance,
      timestamp: new Date().toISOString()
    });
  }

  makePayment(amount, description, recipient) {
    if (this.walletBalance < amount) {
      throw new Error('Insufficient wallet balance');
    }

    const previousBalance = this.walletBalance;
    this.walletBalance -= amount;

    this.paymentHistory.unshift({
      amount: amount,
      description: description,
      id: `payment_${Date.now()}`,
      newBalance: this.walletBalance,
      previousBalance: previousBalance,
      recipient: recipient,
      timestamp: new Date().toISOString(),
      type: 'purchase'
    });
  }

  getRecentTransactions(limit = 10) {
    const allTransactions = [
      ...this.topUpHistory.map(t => ({ ...t, type: 'topup' })),
      ...this.paymentHistory
    ].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    
    return allTransactions.slice(0, limit);
  }
}

// Wallet Service Class
class WalletService {
  constructor(userEmail) {
    this.userEmail = userEmail;
    this.safeEmail = this.userEmail.replace(/\./g, ',');
    this.subscription = null;
    this.errorMessage = "";
    this.db = getDatabase();
  }

  async initialize() {
    try {
      await this.fetchSubscription();
      return true;
    } catch (error) {
      console.error('Failed to initialize wallet service:', error);
      return false;
    }
  }

  async fetchSubscription() {
    try {
      const snapshot = await get(
        ref(this.db, `paymentsubscriptions/${this.safeEmail}`)
      );
      if (snapshot.exists()) {
        const data = snapshot.val();
        this.subscription = new Subscription({
          ...data,
          cardName: data.cardName || "",
          cardNumber: data.cardNumber || "",
          expiryDate: data.expiryDate || "",
          cvv: data.cvv || "",
          walletBalance: data.walletBalance || 0,
          topUpHistory: data.topUpHistory || [],
          paymentHistory: data.paymentHistory || []
        });
        return this.subscription;
      }
      return null;
    } catch (err) {
      console.error(err);
      this.errorMessage = "Failed to fetch subscription.";
      return null;
    }
  }

  async makePayment(amount, description = 'Shopping Cart Purchase', recipient = 'AllCare Shop') {
    if (!this.subscription) {
      this.errorMessage = "No subscription found. Please create a subscription first.";
      return false;
    }

    try {
      this.subscription.makePayment(amount, description, recipient);
      await this.updateSubscriptionInDB();
      return true;
    } catch (err) {
      console.error(err);
      this.errorMessage = err.message || "Failed to process payment.";
      return false;
    }
  }

  async updateSubscriptionInDB() {
    if (!this.subscription) return false;
    
    try {
      const subscriptionData = {
        id: this.subscription.id,
        active: this.subscription.active,
        autoPayment: this.subscription.autoPayment,
        nextPaymentDate: this.subscription.nextPaymentDate,
        paymentMethod: this.subscription.paymentMethod,
        paymentFailed: this.subscription.paymentFailed,
        cardName: this.subscription.cardName,
        cardNumber: this.subscription.cardNumber,
        expiryDate: this.subscription.expiryDate,
        cvv: this.subscription.cvv,
        walletBalance: this.subscription.walletBalance,
        topUpHistory: this.subscription.topUpHistory,
        paymentHistory: this.subscription.paymentHistory,
        subscriptionPlan: this.subscription.subscriptionPlan,
        startDate: this.subscription.startDate
      };

      await set(
        ref(this.db, `paymentsubscriptions/${this.safeEmail}`),
        subscriptionData
      );
      return true;
    } catch (err) {
      console.error(err);
      this.errorMessage = "Failed to update subscription.";
      return false;
    }
  }

  getWalletBalance() {
    return this.subscription ? this.subscription.walletBalance : 0;
  }

  hasSufficientBalance(amount) {
    if (!this.subscription) return false;
    return this.subscription.walletBalance >= amount;
  }

  getErrorMessage() {
    return this.errorMessage;
  }

  clearError() {
    this.errorMessage = "";
  }
}

// Address Service Class
class AddressService {
  constructor(userEmail) {
    this.userEmail = userEmail;
    this.safeEmail = this.userEmail.replace(/\./g, '_');
    this.db = getDatabase();
  }

  async getAddresses() {
    try {
      const snapshot = await get(
        ref(this.db, `Account/${this.safeEmail}/addresses`)
      );
      
      if (snapshot.exists()) {
        const addresses = [];
        snapshot.forEach((childSnapshot) => {
          addresses.push({
            id: childSnapshot.key,
            ...childSnapshot.val()
          });
        });
        return addresses;
      }
      return [];
    } catch (error) {
      console.error('Error fetching addresses:', error);
      return [];
    }
  }

  async saveAddress(addressData) {
    try {
      const addressesRef = ref(this.db, `Account/${this.safeEmail}/addresses`);
      const newAddressRef = push(addressesRef);
      
      const addressWithId = {
        ...addressData,
        id: newAddressRef.key,
        createdAt: new Date().toISOString()
      };
      
      await set(newAddressRef, addressWithId);
      return addressWithId;
    } catch (error) {
      console.error('Error saving address:', error);
      throw error;
    }
  }

  async updateAddress(addressId, addressData) {
    try {
      const addressRef = ref(this.db, `Account/${this.safeEmail}/addresses/${addressId}`);
      await set(addressRef, {
        ...addressData,
        updatedAt: new Date().toISOString()
      });
      return true;
    } catch (error) {
      console.error('Error updating address:', error);
      throw error;
    }
  }

  async deleteAddress(addressId) {
    try {
      const addressRef = ref(this.db, `Account/${this.safeEmail}/addresses/${addressId}`);
      await set(addressRef, null);
      return true;
    } catch (error) {
      console.error('Error deleting address:', error);
      throw error;
    }
  }

  async setDefaultAddress(addressId) {
    try {
      // First, remove default from all addresses
      const addresses = await this.getAddresses();
      const updatePromises = addresses.map(address => {
        if (address.id !== addressId && address.isDefault) {
          return this.updateAddress(address.id, { ...address, isDefault: false });
        }
        return Promise.resolve();
      });

      await Promise.all(updatePromises);

      // Set the new default
      const addressToUpdate = addresses.find(addr => addr.id === addressId);
      if (addressToUpdate) {
        await this.updateAddress(addressId, { ...addressToUpdate, isDefault: true });
      }

      return true;
    } catch (error) {
      console.error('Error setting default address:', error);
      throw error;
    }
  }
}
export { WalletService, AddressService, Subscription };
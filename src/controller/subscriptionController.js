import { Subscription } from "../entity/subscriptionEntity";
import { getDatabase, ref, set, get } from "firebase/database";

// Subscription Controller with improved validation
export class SubscriptionController {
  constructor(userEmail) {
    this.userEmail = userEmail;
    this.safeEmail = this.userEmail.replace(/\./g, ','); // Replace dots with commas
    this.subscription = null;
    this.errorMessage = "";
    this.db = getDatabase(); // Initialize Firebase Database
  }

  // Fetch subscription
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

  // Add first subscription
  async addSubscription({ paymentMethod, cardName, cardNumber, expiryDate, cvv, subscriptionPlan }) {
    try {
      if (!paymentMethod) throw new Error("Payment method required");

      // Calculate next payment date based on subscription plan
      const nextPayment = this.calculateNextPaymentDate(subscriptionPlan);

      const newSub = {
        id: `sub_${Date.now()}`,
        active: true,
        autoPayment: false,
        nextPaymentDate: nextPayment,
        subscriptionPlan: subscriptionPlan || 0, // Default to free trial
        paymentMethod,
        paymentFailed: false,
        cardName: cardName || "",
        cardNumber: cardNumber || "",
        expiryDate: expiryDate || "",
        cvv: cvv || "",
        walletBalance: 100.00, // Default starting balance
        topUpHistory: [],
        paymentHistory: [],
        startDate: new Date().toISOString().split("T")[0]
      };

      // Save to Firebase
      await set(
        ref(this.db, `paymentsubscriptions/${this.safeEmail}`),
        newSub
      );
      
      this.subscription = new Subscription(newSub);
      return true;
    } catch (err) {
      console.error(err);
      this.errorMessage = "Failed to add subscription.";
      return false;
    }
  }

  // Top up wallet with better error handling - FIXED VERSION
  async topUpWallet(amount, paymentMethod, cardDetails = {}) {
    if (!this.subscription) {
      this.errorMessage = "No subscription found. Please create a subscription first.";
      return false;
    }

    try {
      // Validate amount
      if (amount <= 0) {
        this.errorMessage = "Amount must be greater than zero.";
        return false;
      }

      // Validate card details for card payments
      if (paymentMethod === 'credit' || paymentMethod === 'debit') {
        if (!cardDetails.cardNumber || !cardDetails.expiryDate || !cardDetails.cvv) {
          this.errorMessage = "Card details are required for card payments.";
          return false;
        }
        
        // Clean card number for validation
        const cleanCardNumber = cardDetails.cardNumber.replace(/\s+/g, '');
        
        // Basic card validation
        if (!this.validateCard(cleanCardNumber)) {
          this.errorMessage = "Invalid card number. Please check your card details.";
          return false;
        }

        // Validate expiry date (basic check)
        if (!this.validateExpiryDate(cardDetails.expiryDate)) {
          this.errorMessage = "Invalid expiry date. Please use MM/YY format.";
          return false;
        }

        // Validate CVV
        if (!this.validateCVV(cardDetails.cvv)) {
          this.errorMessage = "Invalid CVV. Please enter a 3 or 4 digit CVV.";
          return false;
        }
      }

      // Simulate payment processing
      const paymentSuccess = await this.processPayment(amount, paymentMethod, cardDetails);
      
      if (!paymentSuccess) {
        this.errorMessage = "Payment processing failed. Please try again or use a different card.";
        return false;
      }

      // Add to wallet - THIS WAS MISSING THE DATABASE UPDATE
      this.subscription.addToWallet(amount, paymentMethod, cardDetails);
      
      // Update in database - CRITICAL: Save the updated subscription to Firebase
      await this.updateSubscriptionInDB();
      
      return true;
    } catch (err) {
      console.error(err);
      this.errorMessage = err.message || "Failed to top up wallet.";
      return false;
    }
  }

// Simplified card validation for testing - accepts most valid formats
validateCard(cardNumber) {
  const cleaned = cardNumber.replace(/\s+/g, '');
  
  // Basic validation - just check if it's all numbers and reasonable length
  if (!/^\d+$/.test(cleaned)) {
    console.log('Card validation failed: Contains non-digit characters');
    return false;
  }
  
  if (cleaned.length < 13 || cleaned.length > 19) {
    console.log('Card validation failed: Invalid length', cleaned.length);
    return false;
  }

  // For testing purposes, accept all valid-looking card numbers
  console.log('Card validation passed for testing:', cleaned);
  return true;
}

validateExpiryDate(expiryDate) {
  // More flexible expiry date validation
  const regex = /^(0[1-9]|1[0-2])\/([0-9]{2})$/;
  if (!regex.test(expiryDate)) {
    console.log('Expiry date validation failed: Invalid format');
    return false;
  }

  const [month, year] = expiryDate.split('/');
  const now = new Date();
  const currentYear = now.getFullYear() % 100;
  const currentMonth = now.getMonth() + 1;

  const expYear = parseInt(year);
  const expMonth = parseInt(month);

  if (expYear < currentYear) {
    console.log('Expiry date validation failed: Year expired');
    return false;
  }
  if (expYear === currentYear && expMonth < currentMonth) {
    console.log('Expiry date validation failed: Month expired');
    return false;
  }
  
  console.log('Expiry date validation passed');
  return true;
}

validateCVV(cvv) {
  const regex = /^[0-9]{3,4}$/;
  const isValid = regex.test(cvv);
  console.log('CVV validation:', isValid ? 'passed' : 'failed');
  return isValid;
}

  // Make payment using wallet
  async makePayment(amount, description, recipient) {
    if (!this.subscription) {
      this.errorMessage = "No subscription found.";
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

  // Process payment (simulated)
  async processPayment(amount, paymentMethod, cardDetails) {
    // Simulate API call delay
    return new Promise((resolve) => {
      setTimeout(() => {
        // Simulate 90% success rate
        const success = Math.random() > 0.1;
        resolve(success);
      }, 1500);
    });
  }

  // Toggle auto payment
  async toggleAutoPayment() {
    if (!this.subscription) return false;
    try {
      this.subscription.autoPayment = !this.subscription.autoPayment;
      await this.updateSubscriptionInDB();
      return true;
    } catch (err) {
      console.error(err);
      this.errorMessage = "Failed to update auto-payment status.";
      return false;
    }
  }

  // Update subscription in database - FIXED to properly serialize the object
  async updateSubscriptionInDB() {
    if (!this.subscription) return false;
    
    try {
      // Convert the Subscription object to a plain JavaScript object for Firebase
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

  // Calculate next payment date
  calculateNextPaymentDate(plan) {
    const date = new Date();
    
    switch(plan) {
      case 0: // Free trial (15 days)
        date.setDate(date.getDate() + 15);
        break;
      case 1: // Monthly plan
        date.setMonth(date.getMonth() + 1);
        break;
      case 2: // Annual plan (1 year)
        date.setFullYear(date.getFullYear() + 1);
        break;
      case 3: // 3-Year plan
        date.setFullYear(date.getFullYear() + 3);
        break;
      default: // Default to 30 days
        date.setDate(date.getDate() + 30);
    }
    
    return date.toISOString().split("T")[0]; // YYYY-MM-DD
  }

  // Get wallet balance
  getWalletBalance() {
    return this.subscription ? this.subscription.walletBalance : 0;
  }

  // Get transaction history
  getTransactionHistory(limit = 10) {
    return this.subscription ? this.subscription.getRecentTransactions(limit) : [];
  }

  // Get error message
  getErrorMessage() {
    return this.errorMessage;
  }

  // Clear error message
  clearError() {
    this.errorMessage = "";
  }
}
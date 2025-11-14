import React, { useState, useEffect } from "react";
import {
  Shield,
  CreditCard,
  Bell,
  CheckCircle,
  XCircle,
  PlusCircle,
} from "lucide-react";
import { QRCodeCanvas } from "qrcode.react";
import { SubscriptionController } from "../controller/subscriptionController";
import Footer from "../footer";

export default function ManageSecureSubscriptionPage() {
  const [controller, setController] = useState(null);
  const [subscription, setSubscription] = useState(null);
  const [message, setMessage] = useState("");
  const [editing, setEditing] = useState(false);
  const [showQr, setShowQr] = useState(false);
  const [qrValue, setQrValue] = useState("");

  const [paymentMethod, setPaymentMethod] = useState("");
  const [cardName, setCardName] = useState("");
  const [cardNumber, setCardNumber] = useState("");
  const [expiryDate, setExpiryDate] = useState("");
  const [cvv, setCvv] = useState("");

  const userEmail = localStorage.getItem("userEmail");
  const singaporePaymentMethods = [
    "Visa",
    "Mastercard",
    "American Express",
    "Diners Club",
    "PayNow",
    "GrabPay",
    "Apple Pay",
    "Google Pay",
  ];

  useEffect(() => {
    async function loadSubscription() {
      if (!userEmail) {
        setMessage("No user email found. Please login first.");
        return;
      }
      const subController = new SubscriptionController(userEmail);
      const sub = await subController.fetchSubscription();
      setController(subController);
      setSubscription(sub);
      if (sub) {
        setPaymentMethod(sub.paymentMethod || "");
        setCardName(sub.cardName || "");
        setCardNumber(sub.cardNumber || "");
        setExpiryDate(sub.expiryDate || "");
        setCvv(sub.cvv || "");
      }
    }
    loadSubscription();
  }, [userEmail]);

  const toggleAutoPayment = async () => {
    if (!controller) return;
    const success = await controller.toggleAutoPayment();
    if (success) {
      setSubscription({ ...controller.subscription });
      setMessage(
        controller.subscription.autoPayment
          ? "Auto-payment enabled."
          : "Auto-payment disabled."
      );
    } else {
      setMessage(controller.errorMessage);
    }
    setTimeout(() => setMessage(""), 4000);
  };

  const handlePayNow = async () => {
    if (!controller) return;

    if (
      subscription.paymentMethod === "PayNow" ||
      subscription.paymentMethod === "GrabPay"
    ) {
      const qrData = await controller.getPaymentQRCode(); // Implement this in your controller
      setQrValue(qrData);
      setShowQr(true);
    } else {
      const success = await controller.payNow();
      setSubscription({ ...controller.subscription });
      setMessage(
        success
          ? "Payment successful! Subscription renewed."
          : "Payment failed. Please update your payment method."
      );
      setTimeout(() => setMessage(""), 5000);
    }
  };

  const handleAddSubscription = async () => {
    if (!controller || !paymentMethod) {
      setMessage("Please select a payment method.");
      return;
    }
    const success = await controller.addSubscription({ paymentMethod });
    if (success) {
      setSubscription({ ...controller.subscription });
      setMessage("Subscription added successfully!");
    } else {
      setMessage(controller.errorMessage);
    }
    setTimeout(() => setMessage(""), 4000);
  };

  const handleEditClick = () => setEditing(true);

  const handleCancel = () => {
    if (subscription) {
      setPaymentMethod(subscription.paymentMethod || "");
      setCardName(subscription.cardName || "");
      setCardNumber(subscription.cardNumber || "");
      setExpiryDate(subscription.expiryDate || "");
      setCvv(subscription.cvv || "");
    }
    setEditing(false);
  };

  const handleSave = async () => {
  if (!controller || !subscription) return;

  const updatedSub = {
    ...subscription,
    paymentMethod,
    cardName,
    cardNumber,
    expiryDate,
    cvv,
  };

  const success = await controller.updateSubscription(updatedSub);
  if (success) {
    setSubscription({ ...controller.subscription });
    setEditing(false);
    setMessage("Subscription updated successfully!");
  } else {
    setMessage(controller.errorMessage || "Failed to update subscription.");
  }

  setTimeout(() => setMessage(""), 4000);
};


  if (!controller) {
    return (
      <div style={styles.wrapper}>
        <h1 style={styles.heading}>Manage Secure Subscription</h1>
        <p>Loading subscription...</p>
      </div>
    );
  }

  if (!subscription) {
    return (
      <>
        <div style={styles.wrapper}>
          <h1 style={styles.heading}>Manage Secure Subscription</h1>
          {message && (
            <div style={{ ...styles.alert, ...styles.alertError }}>
              <XCircle /> {message}
            </div>
          )}
          <p>You do not have a subscription yet.</p>
          <select
            value={paymentMethod}
            onChange={(e) => setPaymentMethod(e.target.value)}
            style={styles.select}
          >
            <option value="">Select Payment Method</option>
            {singaporePaymentMethods.map((method) => (
              <option key={method} value={method}>
                {method}
              </option>
            ))}
          </select>
          <button style={styles.btnPrimary} onClick={handleAddSubscription}>
            <PlusCircle size={16} /> Add Subscription
          </button>
        </div>
        <Footer />
      </>
    );
  }

  return (
    <>
      <div style={styles.wrapper}>
        <h1 style={styles.heading}>Manage Secure Subscription</h1>

        {message && (
          <div
            style={{
              ...styles.alert,
              ...(subscription.paymentFailed
                ? styles.alertError
                : styles.alertSuccess),
            }}
          >
            {subscription.paymentFailed ? <XCircle /> : <CheckCircle />}
            <span>{message}</span>
          </div>
        )}

        <div style={styles.card}>
          <div style={styles.info}>
            <p>
              <Shield size={16} /> Status:{" "}
              <strong>{subscription.active ? "Active" : "Disabled"}</strong>
            </p>
            <p>
              <Bell size={16} /> Next Payment Date:{" "}
              {subscription.nextPaymentDate || "N/A"}
            </p>

            {!editing ? (
              <>
                <p>
                  <CreditCard size={16} /> Payment Method:{" "}
                  {subscription.paymentMethod || "N/A"}
                </p>
                <p>Cardholder Name: {subscription?.cardName || "N/A"}</p>
                <p>
                  Card Number:{" "}
                  {subscription?.cardNumber
                    ? "**** **** **** " + subscription.cardNumber.slice(-4)
                    : "N/A"}
                </p>
                <p>Expiry: {subscription?.expiryDate || "N/A"}</p>
              </>
            ) : (
              <>
                <p>
                  Payment Method:{" "}
                  <select
                    value={paymentMethod}
                    onChange={(e) => setPaymentMethod(e.target.value)}
                    style={styles.select}
                  >
                    <option value="">Select Payment Method</option>
                    {singaporePaymentMethods.map((method) => (
                      <option key={method} value={method}>
                        {method}
                      </option>
                    ))}
                  </select>
                </p>
                <p>
                  Cardholder Name:{" "}
                  <input
                    value={cardName}
                    onChange={(e) => setCardName(e.target.value)}
                  />
                </p>
                <p>
                  Card Number:{" "}
                  <input
                    value={cardNumber}
                    onChange={(e) => setCardNumber(e.target.value)}
                  />
                </p>
                <p>
                  Expiry:{" "}
                  <input
                    value={expiryDate}
                    onChange={(e) => setExpiryDate(e.target.value)}
                  />
                </p>
                <p>
                  CVV:{" "}
                  <input
                    value={cvv}
                    onChange={(e) => setCvv(e.target.value)}
                    type="password"
                  />
                </p>
              </>
            )}
          </div>

          <div style={styles.actions}>
            <button style={styles.btnSecondary} onClick={toggleAutoPayment}>
              {subscription.autoPayment
                ? "Disable Auto-Payment"
                : "Enable Auto-Payment"}
            </button>

            {!editing && (
              <button style={styles.btnPrimary} onClick={handleEditClick}>
                Update Subscription
              </button>
            )}

            {editing && (
              <>
                <button style={styles.btnPrimary} onClick={handleSave}>
                  Save
                </button>
                <button style={styles.btnSecondary} onClick={handleCancel}>
                  Cancel
                </button>
              </>
            )}

            {subscription.paymentFailed && (
              <button style={styles.btnPrimary} onClick={handlePayNow}>
                Pay Now
              </button>
            )}
          </div>

          {showQr && (
            <div style={{ textAlign: "center", marginTop: "20px" }}>
              <p>Scan this QR code to pay:</p>
              <QRCodeCanvas value={qrValue} size={200} />
              <button
                style={styles.btnSecondary}
                onClick={() => setShowQr(false)}
              >
                Close
              </button>
            </div>
          )}
        </div>
      </div>
      <Footer />
    </>
  );
}

// Styles
const styles = {
  wrapper: {
    maxWidth: "700px",
    margin: "2rem auto",
    padding: "2rem",
    fontFamily: "Inter, sans-serif",
    background: "white",
    borderRadius: "12px",
    boxShadow: "0 4px 15px rgba(0,0,0,0.05)",
    textAlign: "center",
  },
  heading: {
    color: "#0077b6",
    marginBottom: "1.5rem",
  },
  card: {
    padding: "1.5rem",
    border: "1px solid #cce4ff",
    borderRadius: "12px",
    background: "#f8fbff",
    textAlign: "left",
  },
  info: {
    marginBottom: "20px",
    color: "#005580",
  },
  actions: {
    display: "flex",
    alignItems: "center",
    gap: "10px",
    flexWrap: "wrap",
  },
  btnPrimary: {
    padding: "0.8rem 1.5rem",
    backgroundColor: "#0077b6",
    color: "white",
    border: "none",
    borderRadius: "8px",
    cursor: "pointer",
    fontWeight: "500",
    display: "flex",
    alignItems: "center",
    gap: "6px",
    transition: "background-color 0.2s",
  },
  btnSecondary: {
    padding: "0.8rem 1.5rem",
    backgroundColor: "white",
    border: "2px solid #0077b6",
    color: "#0077b6",
    borderRadius: "8px",
    cursor: "pointer",
    fontWeight: "500",
    transition: "background-color 0.2s",
  },
  select: {
    padding: "0.5rem",
    borderRadius: "6px",
    border: "1px solid #ccc",
    marginBottom: "10px",
    width: "100%",
  },
  alert: {
    display: "flex",
    alignItems: "center",
    padding: "0.8rem",
    borderRadius: "8px",
    marginBottom: "1rem",
    gap: "6px",
    justifyContent: "center",
  },
  alertError: {
    backgroundColor: "#ffe5e5",
    color: "#d00000",
  },
  alertSuccess: {
    backgroundColor: "#e5ffeb",
    color: "#007f0e",
  },
};

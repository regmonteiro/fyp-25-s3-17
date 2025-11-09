import React, { useState, useEffect } from "react";
import {
  createReminder,
  subscribeToReminders,
  deleteReminder,
  updateReminder,
} from "../controller/createEventReminderController";
import Footer from "../footer";
import FloatingAssistant from "../components/floatingassistantChat";

const currentUser = localStorage.getItem("loggedInEmail");

export default function CreateEventReminder() {
  const [title, setTitle] = useState("");
  const [startTime, setStartTime] = useState("");
  const [duration, setDuration] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [loading, setLoading] = useState(false);
  const [reminders, setReminders] = useState([]);
  const [editingId, setEditingId] = useState(null);
  const [editStartTime, setEditStartTime] = useState("");

  const loggedInEmail = localStorage.getItem("loggedInEmail");
  const userKey = loggedInEmail ? loggedInEmail.replace(/\./g, "_") : "anonymous";

  useEffect(() => {
    const unsubscribe = subscribeToReminders(userKey, setReminders);
    return () => unsubscribe();
  }, [userKey]);

  const handleConfirm = async () => {
    if (!title || !startTime || !duration) {
      setError("Please fill all fields.");
      return;
    }
    setError("");
    setSuccess("");
    setLoading(true);

    try {
      await createReminder(userKey, { title, startTime, duration });
      setSuccess("Reminder created successfully!");
      setTitle("");
      setStartTime("");
      setDuration("");
    } catch (err) {
      setError(err.message || "Failed to create reminder. Please try again.");
    }
    setLoading(false);
  };

  const handleDelete = async (id) => {
    setError("");
    setSuccess("");
    setLoading(true);
    try {
      await deleteReminder(userKey, id);
      setSuccess("Reminder deleted!");
    } catch (err) {
      setError("Failed to delete reminder.");
    }
    setLoading(false);
  };

  const startEditing = (id, currentStartTime) => {
    setEditingId(id);
    setEditStartTime(currentStartTime);
  };

  const cancelEditing = () => {
    setEditingId(null);
    setEditStartTime("");
  };

  const saveEdit = async (id) => {
    if (!editStartTime) {
      setError("Start time cannot be empty.");
      return;
    }
    setLoading(true);
    setError("");
    setSuccess("");
    try {
      const reminder = reminders.find((r) => r.id === id);
      if (!reminder) throw new Error("Reminder not found");
      await updateReminder(userKey, id, {
        ...reminder,
        startTime: editStartTime,
      });
      setSuccess("Reminder updated!");
      setEditingId(null);
      setEditStartTime("");
    } catch (err) {
      setError(err.message || "Failed to update reminder.");
    }
    setLoading(false);
  };

  return (
    <div>
    <div
      style={{
        minHeight: "100vh",
        width: "100vw",
        backgroundImage: 'url("/mnt/data/e99c0908-8a29-4812-baab-72a6bfb64f46.png")',
        backgroundSize: "cover",
        backgroundPosition: "center",
        padding: "40px 60px",
        boxSizing: "border-box",
        fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
        overflowY: "auto",
      }}
    >
      <div
        style={{
          maxWidth: 900,
          margin: "0 auto",
          backgroundColor: "rgba(255,255,255,0.9)",
          borderRadius: 20,
          padding: 30,
          boxShadow: "0 6px 20px rgba(0,0,0,0.25)",
        }}
      >
        <h2
          style={{
            textAlign: "center",
            color: "#222",
            fontWeight: "700",
            marginBottom: 24,
            letterSpacing: "1.5px",
            fontSize: 32,
          }}
        >
          Create Reminder
        </h2>

        {/* Input form */}
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: 16,
            marginBottom: 20,
          }}
        >
          <div style={{ gridColumn: "1 / -1" }}>
            <label htmlFor="title" style={{ fontWeight: 600, marginBottom: 6, display: "block", color: "#444" }}>
              Reminder Title
            </label>
            <input
              id="title"
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Enter title"
              style={{
                width: "100%",
                padding: "12px 14px",
                borderRadius: 8,
                border: "1.5px solid #ddd",
                fontSize: 16,
                outlineColor: "#4A90E2",
              }}
            />
          </div>

          <div>
            <label htmlFor="startTime" style={{ fontWeight: 600, marginBottom: 6, display: "block", color: "#444" }}>
              Start Time
            </label>
            <input
              id="startTime"
              type="datetime-local"
              value={startTime}
              onChange={(e) => setStartTime(e.target.value)}
              style={{
                width: "90%",
                padding: "12px 14px",
                borderRadius: 8,
                border: "1.5px solid #ddd",
                fontSize: 16,
                outlineColor: "#4A90E2",
              }}
            />
          </div>

          <div>
            <label htmlFor="duration" style={{ fontWeight: 600, marginBottom: 6, display: "block", color: "#444" }}>
              Duration (minutes)
            </label>
            <input
              id="duration"
              type="number"
              value={duration}
              onChange={(e) => setDuration(e.target.value)}
              min={1}
              placeholder="Enter duration"
              style={{
                width: "100%",
                padding: "12px 14px",
                borderRadius: 8,
                border: "1.5px solid #ddd",
                fontSize: 16,
                outlineColor: "#4A90E2",
              }}
            />
          </div>
        </div>

        {(error || success) && (
          <div
            role="alert"
            style={{
              marginBottom: 20,
              padding: 14,
              borderRadius: 10,
              backgroundColor: error ? "#fce4e4" : "#e7f0fe",
              color: error ? "#c62828" : "#1565c0",
              fontWeight: "600",
              textAlign: "center",
            }}
          >
            {error || success}
          </div>
        )}

        <button
          onClick={handleConfirm}
          disabled={loading}
          style={{
            width: "100%",
            padding: "16px",
            backgroundColor: "#4A90E2",
            color: "white",
            border: "none",
            borderRadius: 30,
            fontWeight: "700",
            fontSize: 18,
            cursor: loading ? "default" : "pointer",
            opacity: loading ? 0.7 : 1,
            marginBottom: 32,
            transition: "background-color 0.3s",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = "#357ABD")}
          onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = "#4A90E2")}
        >
          {loading ? "Creating..." : "Confirm"}
        </button>

        {/* Reminders list */}
        <div>
          <h3
            style={{
              color: "#222",
              borderBottom: "2px solid #4A90E2",
              paddingBottom: 8,
              marginBottom: 20,
              fontWeight: 700,
              fontSize: 24,
            }}
          >
            Your Reminders
          </h3>

          {reminders.length === 0 ? (
            <p style={{ color: "#777", fontStyle: "italic" }}>No reminders yet.</p>
          ) : (
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))",
                gap: 20,
              }}
            >
              {reminders.map(({ id, title, startTime, duration }) => (
                <div
                  key={id}
                  style={{
                    backgroundColor: "rgba(255,255,255,0.9)",
                    borderRadius: 16,
                    padding: 20,
                    boxShadow: "0 3px 10px rgba(0,0,0,0.1)",
                    display: "flex",
                    flexDirection: "column",
                    gap: 8,
                    minHeight: 180,
                    justifyContent: "space-between",
                  }}
                >
                  <div style={{ fontWeight: "700", fontSize: 18, color: "#333" }}>{title}</div>

                  {editingId === id ? (
                    <>
                      <input
                        type="datetime-local"
                        value={editStartTime}
                        onChange={(e) => setEditStartTime(e.target.value)}
                        style={{
                          padding: "10px 12px",
                          borderRadius: 8,
                          border: "1.5px solid #4A90E2",
                          fontSize: 15,
                          marginBottom: 6,
                        }}
                      />
                      <div style={{ fontSize: 14, color: "#555" }}>
                        Duration: {duration} minute{duration > 1 ? "s" : ""}
                      </div>

                      <div style={{ marginTop: 12 }}>
                        <button
                          onClick={() => saveEdit(id)}
                          disabled={loading}
                          style={{
                            marginRight: 10,
                            padding: "8px 18px",
                            backgroundColor: "#4A90E2",
                            border: "none",
                            borderRadius: 20,
                            color: "white",
                            fontWeight: "600",
                            cursor: loading ? "default" : "pointer",
                          }}
                        >
                          Save
                        </button>
                        <button
                          onClick={cancelEditing}
                          disabled={loading}
                          style={{
                            padding: "8px 18px",
                            backgroundColor: "#ccc",
                            border: "none",
                            borderRadius: 20,
                            fontWeight: "600",
                            cursor: loading ? "default" : "pointer",
                          }}
                        >
                          Cancel
                        </button>
                      </div>
                    </>
                  ) : (
                    <>
                      <div style={{ fontSize: 14, color: "#555" }}>
                        Start: {new Date(startTime).toLocaleString()}
                      </div>
                      <div style={{ fontSize: 14, color: "#555" }}>
                        Duration: {duration} minute{duration > 1 ? "s" : ""}
                      </div>
                      <div style={{ marginTop: 12 }}>
                        <button
                          onClick={() => startEditing(id, startTime)}
                          style={{
                            marginRight: 12,
                            padding: "8px 16px",
                            backgroundColor: "#ffd966",
                            border: "none",
                            borderRadius: 20,
                            fontWeight: "600",
                            cursor: "pointer",
                            color: "#333",
                          }}
                        >
                          Update
                        </button>
                        <button
                          onClick={() => handleDelete(id)}
                          style={{
                            padding: "8px 16px",
                            backgroundColor: "#ef5350",
                            border: "none",
                            borderRadius: 20,
                            fontWeight: "600",
                            cursor: "pointer",
                            color: "white",
                          }}
                        >
                          Delete
                        </button>
                      </div>
                    </>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>

     {/* Floating AI Assistant */}
     {currentUser && <FloatingAssistant userEmail={currentUser} />}
    

          <Footer />
    </div>
  );
}

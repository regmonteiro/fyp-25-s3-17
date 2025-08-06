// src/components/ViewServicesPage.js
import React, { useEffect, useState } from "react";
import "../components/viewServicesPage.css";
import { useNavigate } from "react-router-dom";
import { fetchAllServices } from "../controller/viewServicesController";

function ViewServicesPage() {
  const [services, setServices] = useState([]);
  const [error, setError] = useState("");
  const [expandedId, setExpandedId] = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    async function loadServices() {
      const result = await fetchAllServices();
      if (!result.success) {
        setError(result.error);
      } else {
        setServices(result.data);
      }
    }

    loadServices();
  }, []);

  const handleViewDetails = (id) => {
    const isLoggedIn = localStorage.getItem("isLoggedIn") === "true";

    if (!isLoggedIn) {
      alert("Please log in or sign up to view detailed information and access features.");
      navigate("/login");
      return;
    }

    setExpandedId((prev) => (prev === id ? null : id));
  };

  return (
    <div className="services-page">
      <h1 className="services-title">AllCare Platform Services</h1>
      <p className="services-subtitle">
        Designed to empower older adults with comfort, support, and digital ease through smart AI assistance.
      </p>

      {error && <p style={{ color: "red", textAlign: "center" }}>{error}</p>}

      <div className="services-list">
        {services.map((service) => (
          <div className="service-card" key={service.id}>
            <h3 className="service-title">{service.title}</h3>
            <p className="service-description">
              {expandedId === service.id
                ? (service.details || service.description)
                : service.description.length > 70
                ? service.description.slice(0, 70) + "..."
                : service.description}
            </p>

            <button
              className="service-btn"
              onClick={() => handleViewDetails(service.id)}
            >
              {expandedId === service.id ? "Hide Details" : "View Details"}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

export default ViewServicesPage;

// src/controller/viewServicesController.js
import { ref, get, set, push, update, remove } from "firebase/database";
import { database } from "../firebaseConfig";
import { serviceEntity } from "../entity/viewServiceEntity";

// Fetch all services
export async function fetchAllServices() {
  try {
    const servicesRef = ref(database, "Services");
    const snapshot = await get(servicesRef);

    if (!snapshot.exists()) {
      return { success: false, error: "No services found." };
    }

    const data = snapshot.val();
    console.log("Raw Firebase data structure:", data);
    
    // Log each service with all its properties
    Object.entries(data).forEach(([id, service]) => {
      console.log(`Service ${id} properties:`, Object.keys(service));
      console.log(`Service ${id} full data:`, service);
    });

    const servicesArray = Object.entries(data).map(([id, rawService]) => {
      // Debug each property
      console.log(`Service ${id} title:`, rawService?.title);
      console.log(`Service ${id} description:`, rawService?.description);
      console.log(`Service ${id} details:`, rawService?.details);
      
      return { 
        id, 
        title: rawService?.title || "No Title",
        description: rawService?.description || "No Description",
        details: rawService?.details || ""
      };
    });

    return {
      success: true,
      data: servicesArray,
    };
  } catch (err) {
    console.error("Error fetching services:", err);
    return {
      success: false,
      error: err.message || "Failed to load services.",
    };
  }
}

// Create new service
export async function createService(serviceData) {
  try {
    // Fetch existing services to determine next number
    const servicesRef = ref(database, "Services");
    const snapshot = await get(servicesRef);
    
    let nextServiceNumber = 1;
    if (snapshot.exists()) {
      const services = snapshot.val();
      const serviceKeys = Object.keys(services);
      
      // Extract numbers from existing service keys
      const serviceNumbers = serviceKeys.map(key => {
        const match = key.match(/service(\d+)/i);
        return match ? parseInt(match[1]) : 0;
      }).filter(num => num > 0);
      
      nextServiceNumber = serviceNumbers.length > 0 ? Math.max(...serviceNumbers) + 1 : 1;
    }

    const serviceId = `service${nextServiceNumber}`;
    const serviceRef = ref(database, `Services/${serviceId}`);

    // Extract only the data properties
    const serviceDataToSave = {
      title: serviceData.title,
      description: serviceData.description,
      details: serviceData.details || ""
    };

    await set(serviceRef, serviceDataToSave);
    
    return { 
      success: true, 
      data: { id: serviceId, ...serviceDataToSave },
      message: "Service created successfully!"
    };
  } catch (err) {
    console.error("Error creating service:", err);
    return {
      success: false,
      error: err.message || "Failed to create service.",
    };
  }
}

// Update existing service
export async function updateService(id, serviceData) {
  try {
    const serviceRef = ref(database, `Services/${id}`);
    const serviceSnapshot = await get(serviceRef);
    
    if (!serviceSnapshot.exists()) {
      throw new Error("Service not found.");
    }

    // Extract only the data properties
    const serviceDataToSave = {
      title: serviceData.title,
      description: serviceData.description,
      details: serviceData.details || ""
    };

    await update(serviceRef, serviceDataToSave);
    
    return { 
      success: true, 
      data: { id, ...serviceDataToSave },
      message: "Service updated successfully!"
    };
  } catch (err) {
    console.error("Error updating service:", err);
    return {
      success: false,
      error: err.message || "Failed to update service.",
    };
  }
}

// Delete service
export async function deleteService(id) {
  try {
    const serviceRef = ref(database, `Services/${id}`);
    const serviceSnapshot = await get(serviceRef);
    
    if (!serviceSnapshot.exists()) {
      throw new Error("Service not found.");
    }

    await remove(serviceRef);
    
    return { 
      success: true,
      message: "Service deleted successfully!"
    };
  } catch (err) {
    console.error("Error deleting service:", err);
    return {
      success: false,
      error: err.message || "Failed to delete service.",
    };
  }
}
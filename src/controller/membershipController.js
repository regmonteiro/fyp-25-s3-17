// src/controller/membershipController.js
import { database } from '../firebaseConfig';
import { ref, get, set, remove, push, update } from 'firebase/database';

export const fetchAllMembershipPlans = async () => {
  try {
    const plansRef = ref(database, 'membershipPlans');
    const snapshot = await get(plansRef);
    
    if (snapshot.exists()) {
      const plansData = snapshot.val();
      const plans = Object.keys(plansData).map(key => ({
        id: key,
        ...plansData[key]
      }));
      
      return {
        success: true,
        data: plans
      };
    } else {
      // Return empty array if no plans exist
      return {
        success: true,
        data: []
      };
    }
  } catch (error) {
    console.error("Error fetching membership plans:", error);
    return {
      success: false,
      error: "Failed to fetch membership plans"
    };
  }
};

export const createMembershipPlan = async (planData) => {
  try {
    const plansRef = ref(database, 'membershipPlans');
    const newPlanRef = push(plansRef);
    
    await set(newPlanRef, {
      ...planData,
      createdAt: new Date().toISOString(),
      lastUpdatedAt: new Date().toISOString()
    });
    
    return {
      success: true,
      data: {
        id: newPlanRef.key,
        ...planData
      }
    };
  } catch (error) {
    console.error("Error creating membership plan:", error);
    return {
      success: false,
      error: "Failed to create membership plan"
    };
  }
};

export const updateMembershipPlan = async (id, planData) => {
  try {
    const planRef = ref(database, `membershipPlans/${id}`);
    const snapshot = await get(planRef);
    
    if (!snapshot.exists()) {
      return {
        success: false,
        error: "Membership plan not found"
      };
    }
    
    await update(planRef, {
      ...planData,
      lastUpdatedAt: new Date().toISOString()
    });
    
    return {
      success: true,
      data: {
        id,
        ...planData
      }
    };
  } catch (error) {
    console.error("Error updating membership plan:", error);
    return {
      success: false,
      error: "Failed to update membership plan"
    };
  }
};

export const deleteMembershipPlan = async (id) => {
  try {
    const planRef = ref(database, `membershipPlans/${id}`);
    const snapshot = await get(planRef);
    
    if (!snapshot.exists()) {
      return {
        success: false,
        error: "Membership plan not found"
      };
    }
    
    await remove(planRef);
    
    return {
      success: true
    };
  } catch (error) {
    console.error("Error deleting membership plan:", error);
    return {
      success: false,
      error: "Failed to delete membership plan"
    };
  }
};
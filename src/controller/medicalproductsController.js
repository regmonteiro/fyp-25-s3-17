// controller/medicalproductsController.js
import { MedicalProductsEntity } from '../entity/medicalproductsEntity.js';
import { getDatabase, ref, get, child, query, orderByChild, equalTo } from "firebase/database";

export class MedicalProductsController {
  constructor() {
    this.collectionName = "MedicalProducts";
    this.db = getDatabase(); // initialize Realtime Database
  }

  // Get all products
  async getAllProducts() {
    try {
      const snapshot = await get(child(ref(this.db), this.collectionName));
      
      if (!snapshot.exists()) {
        return { success: true, data: [] };
      }

      const productsData = snapshot.val();
      const products = Object.entries(productsData).map(([id, data]) =>
        new MedicalProductsEntity({
          id,
          title: data.title,
          description: data.description,
          category: data.category,
          price: data.price,
          oldPrice: data.oldPrice || null,
          discount: data.discount || null,
          img: data.img,
          createdAt: data.createdAt
        })
      );

      return { success: true, data: products };
    } catch (error) {
      console.error("Error fetching products:", error);
      return { success: false, error: error.message || "Failed to fetch products" };
    }
  }

  // Get products by category
  async getProductsByCategory(category) {
    try {
      const q = query(
        ref(this.db, this.collectionName),
        orderByChild("category"),
        equalTo(category)
      );

      const snapshot = await get(q);

      if (!snapshot.exists()) {
        return { success: true, data: [] };
      }

      const productsData = snapshot.val();
      const products = Object.entries(productsData).map(([id, data]) =>
        new MedicalProductsEntity({
          id,
          title: data.title,
          description: data.description,
          category: data.category,
          price: data.price,
          oldPrice: data.oldPrice || null,
          discount: data.discount || null,
          img: data.img,
          createdAt: data.createdAt
        })
      );

      return { success: true, data: products };
    } catch (error) {
      console.error("Error fetching products by category:", error);
      return { success: false, error: error.message || "Failed to fetch products" };
    }
  }

  // Get product by ID
  async getProductById(productId) {
    try {
      const snapshot = await get(child(ref(this.db), `${this.collectionName}/${productId}`));
      
      if (!snapshot.exists()) {
        return { success: false, error: "Product not found" };
      }

      const data = snapshot.val();
      return { 
        success: true, 
        data: new MedicalProductsEntity({
          id: productId,
          title: data.title,
          description: data.description,
          category: data.category,
          price: data.price,
          oldPrice: data.oldPrice || null,
          discount: data.discount || null,
          img: data.img,
          createdAt: data.createdAt
        })
      };
    } catch (error) {
      console.error("Error fetching product:", error);
      return { success: false, error: error.message || "Failed to fetch product" };
    }
  }
}

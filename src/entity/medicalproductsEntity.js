export class MedicalProductsEntity {
  constructor({ 
    id = null, 
    title, 
    description, 
    category, 
    price, 
    oldPrice = null, 
    discount = null, 
    img, 
    createdAt = new Date().toISOString() 
  }) {
    this.id = id;
    this.title = title;
    this.description = description;
    this.category = category;
    this.price = price;
    this.oldPrice = oldPrice;
    this.discount = discount;
    this.img = img;
    this.createdAt = createdAt;
  }

  // Helper method to generate product ID
  static generateProductId(product) {
    return product.title.toLowerCase().replace(/[^a-z0-9]/g, '-');
  }

  // Helper method to extract price value
  static extractPrice(priceText) {
    const priceMatch = priceText.match(/S\$(\d+\.?\d*)/);
    return priceMatch ? parseFloat(priceMatch[1]) : 0.00;
  }
}
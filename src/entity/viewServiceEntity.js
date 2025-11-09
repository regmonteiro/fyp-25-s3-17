// src/entity/viewServiceEntity.js
export function serviceEntity(serviceData) {
  const service = {
    title: serviceData?.title || "",
    description: serviceData?.description || "",
    details: serviceData?.details || ""
  };

  // Add validate method
  service.validate = function() {
    if (!this.title || !this.title.trim()) return "Title is required.";
    if (!this.description || !this.description.trim()) return "Description is required.";
    return null;
  };

  // Add toJSON method to control serialization
  service.toJSON = function() {
    return {
      title: this.title,
      description: this.description,
      details: this.details
    };
  };

  return service;
}
// controller.js
export class ViewLearningResourceController {
  constructor(resources) {
    this.resources = resources;
    this.selectedResource = null;
    this.errorMessage = "";
  }

  getResources() {
    return this.resources;
  }

  selectResource(id) {
    const resource = this.resources.find((r) => r.id === id);
    if (resource) {
      this.selectedResource = resource;
      this.errorMessage = "";
    } else {
      this.errorMessage = "Resource not found.";
    }
  }

  getSelectedResource() {
    return this.selectedResource;
  }

  getErrorMessage() {
    return this.errorMessage;
  }
}
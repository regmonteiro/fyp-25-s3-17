// viewLearningResourceEntity.js
export class LearningResource {
  constructor({ id, title, description, url, available }) {
    this.id = id;
    this.title = title || "Untitled Resource";
    this.description = description || "";
    this.url = url || null;
    this.available = available === true; // force boolean
  }

  isValid() {
    return (
      typeof this.id === "number" &&
      typeof this.title === "string" &&
      typeof this.description === "string" &&
      (typeof this.url === "string" || this.url === null) &&
      typeof this.available === "boolean"
    );
  }
}

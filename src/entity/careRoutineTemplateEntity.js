export class careRoutineTemplateEntity {
  constructor({
    id = null,
    name = '',
    description = '',
    items = [],
    createdBy = '',
    createdAt = new Date().toISOString(),
    lastUpdatedAt = new Date().toISOString(),
    isActive = true
  } = {}) {
    this.id = id;
    this.name = name;
    this.description = description;
    this.items = items;
    this.createdBy = createdBy;
    this.createdAt = createdAt;
    this.lastUpdatedAt = lastUpdatedAt;
    this.isActive = isActive;
  }

  validate() {
    const errors = [];
    
    if (!this.name || this.name.trim().length === 0) {
      errors.push('Template name is required');
    }
    
    if (this.items.length === 0) {
      errors.push('At least one routine item is required');
    }
    
    for (let i = 0; i < this.items.length; i++) {
      const item = this.items[i];
      if (!item.time || !item.title) {
        errors.push(`Item ${i + 1} requires both time and title`);
      }
      
      if (!this.isValidTime(item.time)) {
        errors.push(`Item ${i + 1} has an invalid time format`);
      }
    }
    
    return errors;
  }

  isValidTime(time) {
    const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/;
    return timeRegex.test(time);
  }

  toFirebase() {
    return {
      name: this.name,
      description: this.description,
      items: this.items,
      createdBy: this.createdBy,
      createdAt: this.createdAt,
      lastUpdatedAt: this.lastUpdatedAt,
      isActive: this.isActive
    };
  }

  static fromFirebase(id, data) {
    return new careRoutineTemplateEntity({
      id,
      name: data.name,
      description: data.description,
      items: data.items || [],
      createdBy: data.createdBy,
      createdAt: data.createdAt,
      lastUpdatedAt: data.lastUpdatedAt,
      isActive: data.isActive !== undefined ? data.isActive : true
    });
  }
}
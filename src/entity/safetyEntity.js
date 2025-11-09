// backend/safetyEntity.js

class SafetyEntity {
  /**
   * @param {string} parameters - Safety parameters for the system
   * @param {string} contentGuidelines - Content guidelines for AI assistant interaction
   */
  constructor(parameters, contentGuidelines) {
    this.parameters = parameters;
    this.contentGuidelines = contentGuidelines;
  }
}

module.exports = SafetyEntity;

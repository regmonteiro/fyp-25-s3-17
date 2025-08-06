// backend/announcementEntity.js

class AnnouncementEntity {
  /**
   * @param {string} id - Unique ID for announcement
   * @param {string} title - Announcement title
   * @param {string} description - Announcement content
   * @param {string[]} userGroups - Target user groups
   * @param {number} createdAt - Timestamp
   */
  constructor(id, title, description, userGroups, createdAt) {
    this.id = id;
    this.title = title;
    this.description = description;
    this.userGroups = userGroups;
    this.createdAt = createdAt;
  }
}

module.exports = AnnouncementEntity;

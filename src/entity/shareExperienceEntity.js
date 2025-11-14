// ===================== ENTITIES =====================

export class ShareExperienceEntity {
  constructor(
    id,
    user,
    title,
    description,
    sharedAt,
    imageUrl = null,
    likes = 0,
    comments = 0
  ) {
    this.id = id; // Can be undefined for new experiences
    this.user = user;
    this.title = title;
    this.description = description;
    this.sharedAt = sharedAt;
    this.imageUrl = imageUrl;
    this.likes = likes;
    this.comments = comments;
  }
}

export class MessageEntity {
  constructor(
    id,
    fromUser,
    toUser,
    content,
    timestamp,
    read = false
  ) {
    this.id = id;
    this.fromUser = fromUser;
    this.toUser = toUser;
    this.content = content;
    this.timestamp = timestamp;
    this.read = read;
  }
}

export class NotificationEntity {
  constructor(
    id,
    toUser,
    fromUser,
    type, // 'message', 'like', 'comment', 'new_post', 'system'
    title,
    message,
    relatedId = null,
    timestamp,
    read = false,
    imageUrl = null
  ) {
    this.id = id;
    this.toUser = toUser;
    this.fromUser = fromUser;
    this.type = type;
    this.title = title;
    this.message = message;
    this.relatedId = relatedId;
    this.timestamp = timestamp;
    this.read = read;
    this.imageUrl = imageUrl;
  }
}

// ===================== FRIEND REQUESTS =====================

export class FriendRequestEntity {
  constructor(id, fromUser, toUser, status = 'pending', createdAt = new Date().toISOString()) {
    this.id = id;
    this.fromUser = fromUser;
    this.toUser = toUser;
    this.status = status; // 'pending', 'accepted', 'rejected'
    this.createdAt = createdAt;
  }
}

export class FriendsEntity {
  constructor(id, user1, user2, createdAt = new Date().toISOString()) {
    this.id = id;
    this.user1 = user1;
    this.user2 = user2;
    this.createdAt = createdAt;
  }
}

// ===================== HELPERS =====================

// Normalize email for Firebase keys
export function normalizeEmail(email) {
  return email.replace(/\./g, "_");
}

// Get user display name from account data
export function getUserDisplayName(email, accounts) {
  const account = accounts[normalizeEmail(email)];
  if (!account) return email; // fallback to raw email
  return `${account.firstname || ""} ${account.lastname || ""}`.trim() || email;
}
// In shareExperienceEntity.js - Add CommentEntity
export class CommentEntity {
  constructor(
    id,
    experienceId,
    userId,
    content,
    timestamp,
    userName = null
  ) {
    this.id = id;
    this.experienceId = experienceId;
    this.userId = userId;
    this.content = content;
    this.timestamp = timestamp;
    this.userName = userName;
  }
}
import React, { useState, useEffect, useRef } from "react";
import { 
  Heart, MessageCircle, Search, User, Edit, Trash2, X, 
  Users, UserCheck, Send, MessageSquare, Bell, BellRing,
  Volume2, VolumeX, Mic, MicOff, Paperclip, Smile,
  Play, Square, MoreVertical, Image, File, XCircle,
  Video, Music, FileText
} from "lucide-react";
import { ShareExperienceController } from "../controller/shareExperienceController";
import { ShareExperienceEntity, MessageEntity, NotificationEntity, FriendRequestEntity, FriendsEntity, CommentEntity } from "../entity/shareExperienceEntity";
import "./shareExperience.css";
import Footer from "../footer";

// Helper: normalize email for storage
const normalizeEmail = (email) => {
  if (!email || typeof email !== 'string') {
    console.warn('Invalid email provided to normalizeEmail:', email);
    return ''; // Return empty string instead of undefined/null
  }
  
  // Trim and convert to lowercase first
  const trimmedEmail = email.trim().toLowerCase();
  
  // Replace dots with underscores for Firebase key compatibility
  return trimmedEmail.replace(/\./g, '_');
};

// Helper: get user display name from Accounts
const getUserDisplayName = (email, accounts) => {  
  if (!email) return "Anonymous";
  const emailKey = normalizeEmail(email);
  const account = accounts[emailKey];
  if (account && account.firstname && account.lastname) {
    return `${account.firstname.charAt(0).toUpperCase() + account.firstname.slice(1)} ${account.lastname.charAt(0).toUpperCase() + account.lastname.slice(1)}`;
  }
  return email.split('@')[0];
};

// Voice control icons
const VolumeUpIcon = () => <Volume2 className="voice-control-icon" />;
const VolumeOffIcon = () => <VolumeX className="voice-control-icon" />;
const MicIcon = () => <Mic className="voice-control-icon" />;
const MicOffIcon = () => <MicOff className="voice-control-icon" />;

// Emoji Picker Component - Make sure this is properly styled
const EmojiPicker = ({ onEmojiSelect, onClose }) => {
  const emojiCategories = {
    "Smileys & Emotion": ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😱", "😨", "😰", "😥", "😓", "🤗", "🤔", "🤭", "🤫", "🤥", "😶", "😐", "😑", "😬", "🙄", "😯", "😦", "😧", "😮", "😲", "🥱", "😴", "🤤", "😪", "😵", "🤐", "🥴", "🤢", "🤮", "🤧", "😷", "🤒", "🤕", "🤑", "🤠"],
    "People & Body": ["👋", "🤚", "🖐️", "✋", "🖖", "👌", "🤌", "🤏", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️", "👍", "👎", "👊", "✊", "🤛", "🤜", "👏", "🙌", "👐", "🤲", "🤝", "🙏", "✍️", "💅", "🤳", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃", "🧠", "🫀", "🫁", "🦷", "🦴", "👀", "👁️", "👅", "👄"],
    "Animals & Nature": ["🐵", "🐒", "🦍", "🦧", "🐶", "🐕", "🦮", "🐩", "🐺", "🦊", "🦝", "🐱", "🐈", "🦁", "🐯", "🐅", "🐆", "🐴", "🐎", "🦄", "🦓", "🦌", "🐮", "🐂", "🐃", "🐄", "🐷", "🐖", "🐗", "🐽", "🐏", "🐑", "🐐", "🐪", "🐫", "🦙", "🦒", "🐘", "🦏", "🦛", "🐭", "🐁", "🐀", "🐹", "🐰", "🐇", "🐿️", "🦫", "🦔", "🦇", "🐻", "🐨", "🐼", "🦥", "🦦", "🦨", "🦘", "🦡", "🐾", "🦃", "🐔", "🐓", "🐣", "🐤", "🐥", "🐦", "🐧", "🕊️", "🦅", "🦆", "🦢", "🦉", "🦤", "🪶", "🦩", "🦜", "🐸", "🐊", "🐢", "🦎", "🐍", "🐲", "🐉", "🦕", "🦖", "🐳", "🐋", "🐬", "🦭", "🐟", "🐠", "🐡", "🦈", "🐙", "🐚", "🪸", "🐌", "🦋", "🐛", "🐜", "🐝", "🪲", "🐞", "🦗", "🪳", "🕷️", "🕸️", "🦂", "🦟", "🪰", "🪱", "🦠", "💐", "🌸", "💮", "🏵️", "🌹", "🥀", "🌺", "🌻", "🌼", "🌷", "🌱", "🪴", "🌲", "🌳", "🌴", "🌵", "🌾", "🌿", "☘️", "🍀", "🍁", "🍂", "🍃"],
    "Food & Drink": ["🍇", "🍈", "🍉", "🍊", "🍋", "🍌", "🍍", "🥭", "🍎", "🍏", "🍐", "🍑", "🍒", "🍓", "🫐", "🥝", "🍅", "🫒", "🥥", "🥑", "🍆", "🥔", "🥕", "🌽", "🌶️", "🫑", "🥒", "🥬", "🥦", "🧄", "🧅", "🍄", "🥜", "🌰", "🍞", "🥐", "🥖", "🫓", "🥨", "🥯", "🥞", "🧇", "🧀", "🍖", "🍗", "🥩", "🥓", "🍔", "🍟", "🍕", "🌭", "🥪", "🌮", "🌯", "🫔", "🥙", "🧆", "🥚", "🍳", "🥘", "🍲", "🫕", "🥣", "🥗", "🍿", "🧈", "🧂", "🥫", "🍱", "🍘", "🍙", "🍚", "🍛", "🍜", "🍝", "🍠", "🍢", "🍣", "🍤", "🍥", "🥮", "🍡", "🥟", "🥠", "🥡", "🦀", "🦞", "🦐", "🦑", "🦪", "🍦", "🍧", "🍨", "🍩", "🍪", "🎂", "🍰", "🧁", "🥧", "🍫", "🍬", "🍭", "🍮", "🍯", "🍼", "🥛", "☕", "🫖", "🍵", "🍶", "🍾", "🍷", "🍸", "🍹", "🍺", "🍻", "🥂", "🥃", "🥤", "🧋", "🧃", "🧉", "🧊"],
    "Activities & Sports": ["⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🪃", "🥅", "⛳", "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹", "🛼", "🛷", "⛸️", "🎿", "⛷️", "🏂", "🪂", "🏋️", "🤼", "🤸", "⛹️", "🤾", "🏌️", "🏇", "🧘", "🏄", "🏊", "🤽", "🚣", "🧗", "🚵", "🚴", "🏆", "🥇", "🥈", "🥉", "🏅", "🎖️", "🏵️", "🎗️", "🎫", "🎟️", "🎪", "🤹", "🎭", "🩰", "🎨", "🎬", "🎤", "🎧", "🎼", "🎹", "🥁", "🪘", "🎷", "🎺", "🎸", "🪕", "🎻", "🎲", "♟️", "🎯", "🎳", "🎮", "🎰"]
  };

  return (
    <div className="emoji-picker-overlay" onClick={onClose}>
      <div className="emoji-picker" onClick={(e) => e.stopPropagation()}>
        <div className="emoji-picker-header">
          <h4>Choose an emoji</h4>
          <button onClick={onClose} className="emoji-picker-close">
            <X size={18} />
          </button>
        </div>
        <div className="emoji-picker-content">
          {Object.entries(emojiCategories).map(([category, emojis]) => (
            <div key={category} className="emoji-category">
              <div className="emoji-category-title">{category}</div>
              <div className="emoji-grid">
                {emojis.map((emoji) => (
                  <button
                    key={emoji}
                    className="emoji-button"
                    onClick={() => onEmojiSelect(emoji)}
                  >
                    {emoji}
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// File Attachment Menu Component
const FileAttachmentMenu = ({ onFileSelect, onClose }) => {
  const fileInputRef = useRef(null);
  const [dragOver, setDragOver] = useState(false);

  const handleFileClick = (type) => {
    if (fileInputRef.current) {
      fileInputRef.current.accept = type === 'image' ? 'image/*' : type === 'video' ? 'video/*' : '*';
      fileInputRef.current.click();
    }
  };

  const handleFileChange = (event) => {
    const file = event.target.files[0];
    if (file) {
      onFileSelect(file);
    }
    event.target.value = ''; // Reset input
  };

  const handleDragOver = (e) => {
    e.preventDefault();
    setDragOver(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    setDragOver(false);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setDragOver(false);
    const file = e.dataTransfer.files[0];
    if (file) {
      onFileSelect(file);
    }
  };

  const attachmentOptions = [
    { type: 'image', label: 'Photo & Video', icon: Image, accept: 'image/*,video/*' },
    { type: 'document', label: 'Document', icon: FileText, accept: '.pdf,.doc,.docx,.txt' },
    { type: 'audio', label: 'Audio', icon: Music, accept: 'audio/*' },
    { type: 'file', label: 'File', icon: File, accept: '*' }
  ];

  return (
    <div className="attachment-menu-overlay" onClick={onClose}>
      <div 
        className={`attachment-menu ${dragOver ? 'drag-over' : ''}`}
        onClick={(e) => e.stopPropagation()}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
      >
        <div className="attachment-menu-header">
          <h4>Attach File</h4>
          <button onClick={onClose} className="attachment-menu-close">
            <X size={18} />
          </button>
        </div>

        <div className="attachment-options">
          {attachmentOptions.map((option) => (
            <button
              key={option.type}
              className="attachment-option"
              onClick={() => handleFileClick(option.type)}
            >
              <div className="attachment-option-icon">
                <option.icon size={24} />
              </div>
              <span>{option.label}</span>
            </button>
          ))}
        </div>

        <div className="drag-drop-area">
          <div className="drag-drop-content">
            <File size={32} />
            <p>Drag and drop files here</p>
            <span>or click options above</span>
          </div>
        </div>

        <input
          type="file"
          ref={fileInputRef}
          onChange={handleFileChange}
          style={{ display: 'none' }}
        />
      </div>
    </div>
  );
};

function FriendsPanel({ currentUserKey, onClose, onStartChat, accounts }) {
  const [activeTab, setActiveTab] = useState("add");
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [friendRequests, setFriendRequests] = useState([]);
  const [friends, setFriends] = useState([]);
  const [caregivers, setCaregivers] = useState([]);
  const [loading, setLoading] = useState(false);

  const currentUserEmail = currentUserKey.replace(/_/g, ".");
  const currentUserAccount = accounts[currentUserKey];
  
  useEffect(() => {
    if (activeTab === "requests") {
      loadFriendRequests();
    } else if (activeTab === "myfriends") {
      // Load both caregivers AND friends for elderly users
      if (currentUserAccount?.userType === "elderly") {
        loadCaregivers();
        loadFriends(); // ADD THIS LINE - Load friends for elderly users too
      } else {
        loadFriends();
      }
    } else if (activeTab === "add") {
      handleSearch("");
    }
  }, [activeTab, currentUserAccount]);

  const loadFriendRequests = () => {
    ShareExperienceController.getFriendRequests(currentUserKey, (requests) => {
      setFriendRequests(requests);
    });
  };

  const loadFriends = () => {
    ShareExperienceController.getFriends(currentUserKey, (friendsList) => {
      console.log('Loaded friends:', friendsList); // Debug log
      setFriends(friendsList);
    });
  };

  const loadCaregivers = () => {
    ShareExperienceController.getCaregiversForElderly(
      currentUserEmail,
      accounts,
      (caregiversList) => {
        console.log('Loaded caregivers:', caregiversList); // Debug log
        setCaregivers(caregiversList);
      }
    );
  };

  const handleSearch = async (query) => {
    setSearchQuery(query);
    setLoading(true);

    try {
      const results = await ShareExperienceController.searchUsers(
        query,
        currentUserEmail,
        accounts
      );

      const resultsWithStatus = await Promise.all(
        results.map(async (user) => {
          const isFriend = await ShareExperienceController.checkFriendshipStatus(
            currentUserKey,
            user.key
          );
          const hasPending = await ShareExperienceController.checkPendingRequest(
            currentUserKey,
            user.key
          );

          return {
            ...user,
            status: isFriend ? "friends" : hasPending ? "pending" : "none",
          };
        })
      );

      setSearchResults(resultsWithStatus);
    } catch (error) {
      console.error("Error searching users:", error);
      setSearchResults([]);
    } finally {
      setLoading(false);
    }
  };

  const sendFriendRequest = async (toUser) => {
    try {
      await ShareExperienceController.sendFriendRequest(currentUserKey, toUser);
      setSearchResults((prev) =>
        prev.map((user) =>
          user.key === toUser ? { ...user, status: "pending" } : user
        )
      );
    } catch (error) {
      console.error("Error sending friend request:", error);
      alert("Failed to send friend request. Please try again.");
    }
  };

  const respondToRequest = async (requestId, status) => {
    try {
      await ShareExperienceController.respondToFriendRequest(requestId, status);
      loadFriendRequests();
      if (status === "accepted") {
        loadFriends(); // Reload friends after accepting request
      }
    } catch (error) {
      console.error("Error responding to friend request:", error);
      alert("Failed to process request. Please try again.");
    }
  };

  // Get friend display name from friend relationship
  const getFriendDisplayInfo = (friend) => {
    const friendEmail = friend.user1 === currentUserKey ? friend.user2 : friend.user1;
    const friendKey = normalizeEmail(friendEmail);
    const friendAccount = accounts[friendKey];
    
    if (friendAccount) {
      return {
        email: friendAccount.email,
        key: friendKey,
        name: getUserDisplayName(friendEmail, accounts),
        userType: friendAccount.userType
      };
    }
    
    return {
      email: friendEmail.replace(/_/g, "."),
      key: friendKey,
      name: friendEmail.split('@')[0],
      userType: 'unknown'
    };
  };

  return (
    <div className="friends-panel-inline">
      <div className="friends-header-inline">
        <h3 className="friends-title-inline">Friends</h3>
        <button onClick={onClose} className="friends-close-button-inline">
          <X className="close-icon" />
        </button>
      </div>

      <div className="friends-tabs-inline">
        <button
          className={`friends-tab-inline ${activeTab === "add" ? "active" : ""}`}
          onClick={() => setActiveTab("add")}
        >
          Add Friends
        </button>
        <button
          className={`friends-tab-inline ${
            activeTab === "requests" ? "active" : ""
          }`}
          onClick={() => setActiveTab("requests")}
        >
          Requests {friendRequests.length > 0 && `(${friendRequests.length})`}
        </button>
        <button
          className={`friends-tab-inline ${
            activeTab === "myfriends" ? "active" : ""
          }`}
          onClick={() => setActiveTab("myfriends")}
        >
          My Friends
        </button>
      </div>

      <div className="friends-content-inline">
        {/* Add Friends Tab */}
        {activeTab === "add" && (
          <div className="add-friends-section-inline">
            <input
              type="text"
              placeholder="Search for elderly users by name or email..."
              value={searchQuery}
              onChange={(e) => handleSearch(e.target.value)}
              className="search-users-input-inline"
            />

            {loading ? (
              <div className="no-results-inline">
                <p>Searching elderly users...</p>
              </div>
            ) : searchResults.length > 0 ? (
              <div className="search-results-inline">
                {searchResults.map((user) => {
                  const status = user.status || "none";
                  return (
                    <div key={user.key} className="user-result-inline">
                      <div className="user-info-inline">
                        <div className="user-avatar-small-inline">
                          <User size={20} />
                        </div>
                        <div className="user-details-small-inline">
                          <h4>{user.name}</h4>
                          <p>Elderly User</p>
                        </div>
                      </div>
                      <button
                        onClick={() => sendFriendRequest(user.key)}
                        disabled={status !== "none"}
                        className={`add-friend-button-inline ${
                          status === "friends"
                            ? "friends"
                            : status === "pending"
                            ? "pending"
                            : "add"
                        }`}
                      >
                        {status === "friends"
                          ? "Friends"
                          : status === "pending"
                          ? "Pending"
                          : "Add Friend"}
                      </button>
                    </div>
                  );
                })}
              </div>
            ) : searchQuery.trim().length >= 1 ? (
              <div className="no-results-inline">
                <Users className="no-results-icon" size={32} />
                <p>No elderly users found matching "{searchQuery}"</p>
              </div>
            ) : (
              <div className="no-results-inline">
                <Users className="no-results-icon" size={32} />
                <p>Search for elderly users to add as friends</p>
              </div>
            )}
          </div>
        )}

        {/* Friend Requests Tab */}
        {activeTab === "requests" && (
          <div className="friend-requests-section-inline">
            {friendRequests.length > 0 ? (
              <div className="friend-requests-list-inline">
                {friendRequests
                  .filter(
                    (request) =>
                      request.status === "pending" &&
                      request.toUser === currentUserKey
                  )
                  .map((request) => (
                    <div
                      key={request.id}
                      className="friend-request-item-inline"
                    >
                      <div className="user-info-inline">
                        <div className="user-avatar-small-inline">
                          <User size={20} />
                        </div>
                        <div className="user-details-small-inline">
                          <h4>
                            {getUserDisplayName(request.fromUser, accounts)}
                          </h4>
                          <p>Wants to be your friend</p>
                        </div>
                      </div>
                      <div className="request-actions-inline">
                        <button
                          onClick={() =>
                            respondToRequest(request.id, "accepted")
                          }
                          className="accept-request-inline"
                        >
                          Accept
                        </button>
                        <button
                          onClick={() =>
                            respondToRequest(request.id, "rejected")
                          }
                          className="reject-request-inline"
                        >
                          Reject
                        </button>
                      </div>
                    </div>
                  ))}
              </div>
            ) : (
              <div className="no-requests-inline">
                <Bell className="no-requests-icon" size={32} />
                <p>No pending friend requests</p>
              </div>
            )}
          </div>
        )}

        {/* My Friends / Caregivers Tab - FIXED VERSION */}
        {activeTab === "myfriends" && (
          <div className="my-friends-section-inline">
            {currentUserAccount?.userType === "elderly" ? (
              <>
                {/* Show Caregivers Section */}
                {caregivers.length > 0 && (
                  <div className="friends-list-inline">
                    <h4 className="section-subtitle-inline">
                      My Caregivers ({caregivers.length})
                    </h4>
                    {caregivers.map((caregiver) => (
                      <div key={caregiver.key} className="friend-item-inline">
                        <div className="user-info-inline">
                          <div className="user-avatar-small-inline">
                            <User size={20} />
                          </div>
                          <div className="user-details-small-inline">
                            <h4>{caregiver.name}</h4>
                            <p>Caregiver</p>
                          </div>
                        </div>
                        <button
                          onClick={() =>
                            onStartChat(caregiver.email, caregiver.name)
                          }
                          className="message-friend-button-inline"
                        >
                          <MessageCircle size={16} />
                          Message
                        </button>
                      </div>
                    ))}
                  </div>
                )}

                {/* Show Friends Section */}
                {friends.length > 0 && (
                  <div className="friends-list-inline" style={{marginTop: '10px'}}>
                    <h4 className="section-subtitle-inline">
                      My Friends ({friends.length})
                    </h4>
                    {friends.map((friend) => {
                      const friendInfo = getFriendDisplayInfo(friend);
                      return (
                        <div key={friend.id} className="friend-item-inline">
                          <div className="user-info-inline">
                            <div className="user-avatar-small-inline">
                              <User size={20} />
                            </div>
                            <div className="user-details-small-inline">
                              <h4>{friendInfo.name}</h4>
                              <p>Friend</p>
                            </div>
                          </div>
                          <button
                            onClick={() =>
                              onStartChat(friendInfo.email, friendInfo.name)
                            }
                            className="message-friend-button-inline"
                          >
                            <MessageCircle size={16} />
                            Message
                          </button>
                        </div>
                      );
                    })}
                  </div>
                )}

                {/* Show empty state if no caregivers AND no friends */}
                {caregivers.length === 0 && friends.length === 0 && (
                  <div className="no-friends-inline">
                    <Users className="no-friends-icon" size={32} />
                    <p>No caregivers or friends yet</p>
                    <p className="empty-state-subtext">
                      Add friends from the "Add Friends" tab
                    </p>
                  </div>
                )}
              </>
            ) : (
              /* For non-elderly users (caregivers/admins) */
              friends.length > 0 ? (
                <div className="friends-list-inline">
                  <h4 className="section-subtitle-inline">
                    My Friends ({friends.length})
                  </h4>
                  {friends.map((friend) => {
                    const friendInfo = getFriendDisplayInfo(friend);
                    return (
                      <div key={friend.id} className="friend-item-inline">
                        <div className="user-info-inline">
                          <div className="user-avatar-small-inline">
                            <User size={20} />
                          </div>
                          <div className="user-details-small-inline">
                            <h4>{friendInfo.name}</h4>
                            <p>Elderly User</p>
                          </div>
                        </div>
                        <button
                          onClick={() =>
                            onStartChat(friendInfo.email, friendInfo.name)
                          }
                          className="message-friend-button-inline"
                        >
                          <MessageCircle size={16} />
                          Message
                        </button>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div className="no-friends-inline">
                  <Users className="no-friends-icon" size={32} />
                  <p>No friends yet</p>
                  <p className="empty-state-subtext">
                    Add friends from the "Add Friends" tab
                  </p>
                </div>
              )
            )}
          </div>
        )}
      </div>
    </div>
  );
}

// Enhanced Messaging Panel Component
function MessagingPanel({ currentUserKey, selectedUser, onClose, onUserSelect, conversations, accounts, audioEnabled, speakText, onNewMessage }) {
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState("");
  const [loading, setLoading] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState("");
  const [isSpeechSupported, setIsSpeechSupported] = useState(true);
  const [currentlyPlaying, setCurrentlyPlaying] = useState(null);
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [showAttachmentMenu, setShowAttachmentMenu] = useState(false);
  const [attachedFiles, setAttachedFiles] = useState([]);
  const [showFriends, setShowFriends] = useState(false);
  const messagesEndRef = useRef(null);
  const recognitionRef = useRef(null);
  const fileInputRef = useRef(null);

  // Initialize speech recognition
  useEffect(() => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    
    if (!SpeechRecognition) {
      setIsSpeechSupported(false);
      console.warn('Speech recognition not supported in this browser');
    } else {
      recognitionRef.current = new SpeechRecognition();
      recognitionRef.current.continuous = false;
      recognitionRef.current.interimResults = true;
      recognitionRef.current.lang = 'en-US';

      recognitionRef.current.onstart = () => {
        setIsListening(true);
        setTranscript("");
      };

      recognitionRef.current.onresult = (event) => {
        let finalTranscript = '';
        let interimTranscript = '';

        for (let i = event.resultIndex; i < event.results.length; i++) {
          const transcript = event.results[i][0].transcript;
          if (event.results[i].isFinal) {
            finalTranscript += transcript;
          } else {
            interimTranscript += transcript;
          }
        }

        setTranscript(finalTranscript || interimTranscript);

        if (finalTranscript) {
          setNewMessage(finalTranscript);
          setTimeout(() => {
            setIsListening(false);
          }, 500);
        }
      };

      recognitionRef.current.onerror = (event) => {
        console.error('Speech recognition error:', event.error);
        setIsListening(false);
        if (event.error === 'not-allowed') {
          alert('Please allow microphone access to use voice messages.');
        }
      };

      recognitionRef.current.onend = () => {
        setIsListening(false);
      };
    }

    return () => {
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
      if ('speechSynthesis' in window) {
        window.speechSynthesis.cancel();
      }
    };
  }, []);

  useEffect(() => {
    if (selectedUser) {
      ShareExperienceController.getMessages(currentUserKey, selectedUser.key, (messageList) => {
        setMessages(messageList);
        ShareExperienceController.markMessagesAsRead(selectedUser.key, currentUserKey);
      });
    }
  }, [selectedUser, currentUserKey]);

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);
  
  const handleSendMessage = async () => {
    if ((!newMessage.trim() && attachedFiles.length === 0) || !selectedUser) return;

    setLoading(true);
    try {
      // Create message with text and file info
      const messageData = {
        content: newMessage.trim(),
        attachments: attachedFiles.map(file => ({
          name: file.name,
          type: file.type,
          size: file.size,
          url: URL.createObjectURL(file) // In real app, upload to server first
        }))
      };

      const message = new MessageEntity(
        null,
        currentUserKey,
        selectedUser.key,
        JSON.stringify(messageData), // Store as JSON string
        new Date().toISOString()
      );

      await ShareExperienceController.sendMessage(message);
      
      // Send notification to the recipient
      const notification = new NotificationEntity(
        null,
        selectedUser.key,
        currentUserKey,
        'message',
        'New Message',
        `${getUserDisplayName(currentUserKey, accounts)} sent you a message`,
        null,
        new Date().toISOString()
      );
      await ShareExperienceController.sendNotification(notification);
      
      // Notify parent component about new message for badge updates
      if (onNewMessage) {
        onNewMessage();
      }
      
      // Reset form
      setNewMessage("");
      setAttachedFiles([]);
    } catch (error) {
      console.error("Error sending message:", error);
    } finally {
      setLoading(false);
    }
  };

  const toggleListening = () => {
    if (!isSpeechSupported) {
      alert("Speech recognition is not supported in your browser. Please use Chrome, Edge, or Safari.");
      return;
    }

    if (isListening) {
      recognitionRef.current.stop();
    } else {
      setTranscript("");
      try {
        recognitionRef.current.start();
      } catch (error) {
        console.error('Error starting speech recognition:', error);
        alert('Error accessing microphone. Please check permissions.');
      }
    }
  };

  const readMessageAloud = (message) => {
    if (currentlyPlaying === message.id) {
      window.speechSynthesis.cancel();
      setCurrentlyPlaying(null);
      return;
    }

    try {
      let textToRead = "";
      
      // Parse the message content to extract actual content
      const messageData = JSON.parse(message.content);
      
      if (messageData.content) {
        textToRead = messageData.content;
      } else if (messageData.attachments && messageData.attachments.length > 0) {
        textToRead = `Sent ${messageData.attachments.length} attachment${messageData.attachments.length > 1 ? 's' : ''}`;
      }
      
      const sender = message.fromUser === currentUserKey ? "You" : getUserDisplayName(message.fromUser, accounts);
      
      setCurrentlyPlaying(message.id);
      
      const utterance = new SpeechSynthesisUtterance(`${sender} said: ${textToRead}`);
      utterance.lang = "en-US";
      utterance.rate = 0.9;
      utterance.pitch = 1;
      utterance.volume = 1;
      
      utterance.onend = () => setCurrentlyPlaying(null);
      utterance.onerror = () => setCurrentlyPlaying(null);
      
      speakText(`${sender} said: ${textToRead}`);
    } catch (error) {
      // Fallback for old message format - show raw content directly
      const textToRead = message.content;
      const sender = message.fromUser === currentUserKey ? "You" : getUserDisplayName(message.fromUser, accounts);
      
      setCurrentlyPlaying(message.id);
      
      const utterance = new SpeechSynthesisUtterance(`${sender} said: ${textToRead}`);
      utterance.lang = "en-US";
      utterance.rate = 0.9;
      utterance.pitch = 1;
      utterance.volume = 1;
      
      utterance.onend = () => setCurrentlyPlaying(null);
      utterance.onerror = () => setCurrentlyPlaying(null);
      
      speakText(`${sender} said: ${textToRead}`);
    }
  };
  

  const handleEmojiSelect = (emoji) => {
    setNewMessage(prev => prev + emoji);
    setShowEmojiPicker(false);
  };

  const handleFileSelect = (file) => {
    if (file.size > 10 * 1024 * 1024) { // 10MB limit
      alert('File size too large. Please select a file smaller than 10MB.');
      return;
    }
    
    setAttachedFiles(prev => [...prev, file]);
    setShowAttachmentMenu(false);
  };

  const removeAttachedFile = (index) => {
    setAttachedFiles(prev => prev.filter((_, i) => i !== index));
  };

  const getFileIcon = (file) => {
    if (file.type.startsWith('image/')) return <Image size={16} />;
    if (file.type.startsWith('video/')) return <Video size={16} />;
    if (file.type.startsWith('audio/')) return <Music size={16} />;
    return <File size={16} />;
  };

  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const formatTime = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const formatDate = (timestamp) => {
    const date = new Date(timestamp);
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    if (date.toDateString() === today.toDateString()) {
      return 'Today';
    } else if (date.toDateString() === yesterday.toDateString()) {
      return 'Yesterday';
    } else {
      return date.toLocaleDateString();
    }
  };

  // Group messages by date
  const groupedMessages = messages.reduce((groups, message) => {
    const date = formatDate(message.timestamp);
    if (!groups[date]) {
      groups[date] = [];
    }
    groups[date].push(message);
    return groups;
  }, {});

  // Render message content - FIXED to show only actual content
  const renderMessageContent = (message) => {
    try {
      const messageData = JSON.parse(message.content);
      
      return (
        <div className="message-content-wrapper">
          {/* Show attachments if any */}
          {messageData.attachments && messageData.attachments.map((attachment, index) => (
            <div key={index} className="message-attachment">
              <div className="attachment-preview">
                {attachment.type.startsWith('image/') ? (
                  <img src={attachment.url} alt={attachment.name} className="attachment-image" />
                ) : (
                  <div className="attachment-file">
                    {getFileIcon(attachment)}
                    <span className="attachment-name">{attachment.name}</span>
                    <span className="attachment-size">{formatFileSize(attachment.size)}</span>
                  </div>
                )}
              </div>
            </div>
          ))}
          
          {/* Show content if it exists and is not empty */}
          {messageData.content && messageData.content.trim() && (
            <div className="message-text">
              {messageData.content}
            </div>
          )}
          
          {/* Show emoji if content is just emoji or empty but has no attachments */}
          {(!messageData.content || !messageData.content.trim()) && 
           (!messageData.attachments || messageData.attachments.length === 0) && (
            <div className="message-text">
              {message.content} {/* Fallback to raw content */}
            </div>
          )}
        </div>
      );
    } catch (error) {
      // Old message format - show raw content directly
      return (
        <div className="message-content-wrapper">
          <div className="message-text">
            {message.content}
          </div>
        </div>
      );
    }
  };

  return (
    <div className="messaging-overlay" style={{marginTop: '50px'}}>
      <div className="messaging-panel">
        <div className="messaging-header">
          <div className="messaging-header-content">
            <button onClick={onClose} className="back-button">
              <X className="back-icon" />
            </button>
            <h3 className="messaging-title">Messages</h3>
            <button 
              onClick={() => setShowFriends(!showFriends)}
              className="friends-toggle-button"
              title={showFriends ? "Hide Friends" : "Show Friends"}
             style={{marginLeft: '20px', color: '#090909ff', textstyle: 'bold'}}>
              <Users size={50} /> Friends
            </button>
          </div>
        </div>

        <div className="messaging-content">
          {/* Friends Panel - Now inside messaging */}
          {showFriends && (
            <div className="friends-panel-container">
              <FriendsPanel 
                currentUserKey={currentUserKey}
                onClose={() => setShowFriends(false)}
                onStartChat={(userKey, userName) => {
                  onUserSelect({ key: normalizeEmail(userKey), name: userName });
                  setShowFriends(false); 
                }}
                accounts={accounts}
              />
            </div>
          )}

          {/* Conversations List */}
          <div className="conversations-sidebar">
            <div className="conversations-header">
              <h4 className="conversations-title">Messages</h4>
            </div>
            <div className="conversations-list">
              {conversations.length === 0 ? (
                <div className="no-conversations">
                  <MessageSquare className="no-conversations-icon" />
                  <p>No conversations yet</p>
                </div>
              ) : (
                conversations.map((conv) => {
                  const partnerName = getUserDisplayName(conv.partner, accounts);
                  return (
                    <div
                      key={conv.partner}
                      className={`conversation-item ${selectedUser?.key === conv.partner ? 'active' : ''}`}
                      onClick={() => onUserSelect({ key: conv.partner, name: partnerName })}
                    >
                      <div className="conversation-avatar">
                        <User className="avatar-icon" />
                      </div>
                      <div className="conversation-info">
                        <div className="conversation-partner">{partnerName}</div>
                        <div className="conversation-preview">
                          {(() => {
                            try {
                              const messageData = JSON.parse(conv.lastMessage.content);
                              if (messageData.content) {
                                return messageData.content.substring(0, 30) + (messageData.content.length > 30 ? '...' : '');
                              } else if (messageData.attachments && messageData.attachments.length > 0) {
                                return `Sent ${messageData.attachments.length} attachment${messageData.attachments.length > 1 ? 's' : ''}`;
                              }
                              return 'Message';
                            } catch (e) {
                              return conv.lastMessage.content.substring(0, 30) + (conv.lastMessage.content.length > 30 ? '...' : '');
                            }
                          })()}
                        </div>
                      </div>
                      <div className="conversation-time">
                        {formatTime(conv.lastMessage.timestamp)}
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* Chat Area */}
          <div className="chat-area">
            {selectedUser ? (
              <>
                <div className="chat-header">
                  <div className="chat-user-info">
                    <div className="chat-user-avatar">
                      <User className="avatar-icon" />
                    </div>
                    <div className="chat-user-details">
                      <h4 className="chat-user-name">{selectedUser.name}</h4>
                      <span className="chat-user-status">Online</span>
                    </div>
                  </div>
                  <div className="chat-header-actions">
                    {audioEnabled && (
                      <button className="call-button" title="Voice call">
                        <MicIcon />
                      </button>
                    )}
                  </div>
                </div>

                {/* Speech Recognition Feedback */}
                {isListening && (
                  <div className="speech-feedback-chat">
                    <div className="listening-indicator-chat">
                      <div className="pulse-animation-small"></div>
                      <span>Listening... Speak your message</span>
                      {transcript && (
                        <div className="transcript-preview">
                          "{transcript}"
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {/* Attached Files Preview */}
                {attachedFiles.length > 0 && (
                  <div className="attached-files-preview">
                    <div className="attached-files-header">
                      <span>Attached files ({attachedFiles.length})</span>
                    </div>
                    <div className="attached-files-list">
                      {attachedFiles.map((file, index) => (
                        <div key={index} className="attached-file-item">
                          <div className="file-icon">
                            {getFileIcon(file)}
                          </div>
                          <div className="file-info">
                            <span className="file-name">{file.name}</span>
                            <span className="file-size">{formatFileSize(file.size)}</span>
                          </div>
                          <button
                            onClick={() => removeAttachedFile(index)}
                            className="remove-file-button"
                            title="Remove file"
                          >
                            <XCircle size={16} />
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                <div className="messages-container">
                  {messages.length === 0 ? (
                    <div className="no-messages">
                      <MessageCircle className="no-messages-icon" />
                      <p>No messages yet. Start the conversation!</p>
                    </div>
                  ) : (
                    Object.entries(groupedMessages).map(([date, dateMessages]) => (
                      <div key={date} className="message-date-group">
                        <div className="date-divider">
                          <span>{date}</span>
                        </div>
                        {dateMessages.map((message) => (
                          <div
                            key={message.id}
                            className={`message-bubble-container ${
                              message.fromUser === currentUserKey ? 'sent' : 'received'
                            }`}
                          >
                            <div className="message-bubble">
                              {renderMessageContent(message)}
                              <div className="message-footer">
                                <span className="message-time">
                                  {formatTime(message.timestamp)}
                                </span>
                                {audioEnabled && (
                                  <button
                                    onClick={() => readMessageAloud(message)}
                                    className={`tts-button ${currentlyPlaying === message.id ? 'playing' : ''}`}
                                    title={currentlyPlaying === message.id ? "Stop playback" : "Read aloud"}
                                  >
                                    {currentlyPlaying === message.id ? <Square size={12} /> : <Play size={12} />}
                                  </button>
                                )}
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    ))
                  )}
                  <div ref={messagesEndRef} />
                </div>

                <div className="message-input-area">
                  <div className="message-input-container">
                    <button 
                      onClick={() => setShowAttachmentMenu(true)}
                      className="attachment-button" 
                      title="Attach file"
                    >
                      <Paperclip size={20} />
                    </button>
                    
                    <div className="input-wrapper">
                      <input
                        type="text"
                        placeholder="Type a message..."
                        value={newMessage}
                        onChange={(e) => setNewMessage(e.target.value)}
                        onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
                        className="message-input"
                        disabled={loading}
                      />
                      {isListening && (
                        <div className="voice-input-indicator">
                          <div className="recording-dot"></div>
                          Recording... Speak now
                        </div>
                      )}
                    </div>
                    
                    <button 
                      onClick={() => setShowEmojiPicker(true)}
                      className="emoji-button" 
                      title="Add emoji"
                    >
                      <Smile size={20} />
                    </button>
                    
                    {audioEnabled && (
                      <button 
                        onClick={toggleListening}
                        className={`voice-message-button ${isListening ? 'recording' : ''}`}
                        title={isListening ? "Stop recording" : "Voice message"}
                        disabled={!isSpeechSupported}
                      >
                        {isListening ? <MicOffIcon /> : <MicIcon />}
                      </button>
                    )}
                    
                    <button
                      onClick={handleSendMessage}
                      disabled={(!newMessage.trim() && attachedFiles.length === 0) || loading}
                      className="send-message-button"
                      title="Send message"
                    >
                      <Send className="send-icon" />
                    </button>
                  </div>
                </div>

                {/* Emoji Picker */}
                {showEmojiPicker && (
                  <EmojiPicker
                    onEmojiSelect={handleEmojiSelect}
                    onClose={() => setShowEmojiPicker(false)}
                  />
                )}

                {/* Attachment Menu */}
                {showAttachmentMenu && (
                  <FileAttachmentMenu
                    onFileSelect={handleFileSelect}
                    onClose={() => setShowAttachmentMenu(false)}
                  />
                )}
              </>
            ) : (
              <div className="no-chat-selected">
                <MessageCircle className="no-chat-icon" />
                <h4>Select a conversation</h4>
                <p>Choose a conversation from the list to start messaging</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

// Notifications Panel Component
function NotificationsPanel({ notifications, onClose, onNotificationClick, onMarkAllAsRead, onDeleteNotification, accounts }) {
  const formatTime = (timestamp) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diffTime = Math.abs(now - date);
    const diffMinutes = Math.floor(diffTime / (1000 * 60));
    const diffHours = Math.floor(diffTime / (1000 * 60 * 60));
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

    if (diffMinutes < 1) return "Just now";
    if (diffMinutes < 60) return `${diffMinutes}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  };

  const getNotificationIcon = (type) => {
    switch (type) {
      case 'message':
        return <MessageCircle className="notification-type-icon message" />;
      case 'like':
        return <Heart className="notification-type-icon like" />;
      case 'comment':
        return <MessageCircle className="notification-type-icon comment" />;
      case 'new_post':
        return <Users className="notification-type-icon new-post" />;
      default:
        return <Bell className="notification-type-icon system" />;
    }
  };

  const unreadCount = notifications.filter(notif => !notif.read).length;

  return (
    <div className="notifications-overlay">
      <div className="notifications-panel">
        <div className="notifications-header">
          <div className="notifications-title-section">
            <h3 className="notifications-title">Notifications</h3>
            {unreadCount > 0 && (
              <span className="unread-count-badge">{unreadCount} unread</span>
            )}
          </div>
          <div className="notifications-actions">
            {unreadCount > 0 && (
              <button onClick={onMarkAllAsRead} className="mark-all-read-button">
                Mark all as read
              </button>
            )}
            <button onClick={onClose} className="notifications-close-button">
              <X className="close-icon" />
            </button>
          </div>
        </div>

        <div className="notifications-content">
          {notifications.length === 0 ? (
            <div className="no-notifications">
              <Bell className="no-notifications-icon" />
              <h4>No notifications yet</h4>
              <p>Your notifications will appear here</p>
            </div>
          ) : (
            <div className="notifications-list">
              {notifications.map((notification) => (
                <div
                  key={notification.id}
                  className={`notification-item ${notification.read ? 'read' : 'unread'}`}
                  onClick={() => onNotificationClick(notification)}
                >
                  <div className="notification-icon">
                    {getNotificationIcon(notification.type)}
                  </div>
                  <div className="notification-content">
                    <div className="notification-title">
                      {notification.title}
                    </div>
                    <div className="notification-message">
                      {notification.message}
                    </div>
                    <div className="notification-time">
                      {formatTime(notification.timestamp)}
                    </div>
                  </div>
                  <button
                    onClick={(e) => onDeleteNotification(notification.id, e)}
                    className="delete-notification-button"
                    title="Delete notification"
                  >
                    <X className="delete-icon" />
                  </button>
                  {!notification.read && (
                    <div className="unread-indicator"></div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function ExperienceCard({ experience, currentUserKey, onLike, onEdit, onDelete, onStartChat, onReadAloud, accounts, audioEnabled }) {
  // ✅ Move ALL hooks to the VERY TOP - no conditionals before hooks
  const [showEditModal, setShowEditModal] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [showComments, setShowComments] = useState(false);
  const [comments, setComments] = useState([]);
  const [newComment, setNewComment] = useState("");
  const [isSubmittingComment, setIsSubmittingComment] = useState(false);
  const [isLiking, setIsLiking] = useState(false);
  const [showFullDescription, setShowFullDescription] = useState(false);

  // ✅ useEffect must be at the top level, not conditional
  useEffect(() => {
    if (experience && showComments) {
      loadComments();
    }
  }, [showComments, experience]);

  // ✅ Now safe to do early return after all hooks
  if (!experience) {
    return <div className="experience-card">Error: Invalid experience data</div>;
  }

  const isOwner = experience.user === currentUserKey;

  // Remove all truncation logic - just use the description directly
  const safeDescription = experience.description || "";

  const loadComments = () => {
    ShareExperienceController.getExperienceComments(experience.id, (commentList) => {
      const commentsWithNames = commentList.map(comment => ({
        ...comment,
        displayName: comment.userName || getUserDisplayName(comment.userId, accounts)
      }));
      setComments(commentsWithNames);
    });
  };

  const handleDelete = async () => {
    try {
      await ShareExperienceController.deleteExperience(experience.id);
      onDelete();
    } catch (error) {
      console.error("Error deleting experience:", error);
    }
    setShowDeleteConfirm(false);
  };

  const handleLike = async () => {
    if (isLiking) return;
    
    setIsLiking(true);
    try {
      await onLike(experience.id, experience.user, experience.likes, experience.liked);
    } catch (error) {
      console.error("Error toggling like:", error);
    } finally {
      setIsLiking(false);
    }
  };

  const handleAddComment = async () => {
    if (!newComment.trim() || isSubmittingComment) return;

    setIsSubmittingComment(true);
    try {
      const comment = new CommentEntity(
        null,
        experience.id,
        currentUserKey,
        newComment.trim(),
        new Date().toISOString(),
        getUserDisplayName(currentUserKey, accounts)
      );

      await ShareExperienceController.addComment(comment);
      setNewComment("");
      loadComments(); // Reload comments to show the new one
    } catch (error) {
      console.error("Error adding comment:", error);
      alert("Failed to add comment. Please try again.");
    } finally {
      setIsSubmittingComment(false);
    }
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffTime = Math.abs(now - date);
    const diffMinutes = Math.floor(diffTime / (1000 * 60));
    const diffHours = Math.floor(diffTime / (1000 * 60 * 60));
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffMinutes < 1) return "Just now";
    if (diffMinutes < 60) return `${diffMinutes}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays === 1) return "Yesterday";
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  };

  const handleReadAloud = () => {
    onReadAloud(experience);
  };

  return (
    <>
      <div className="experience-card">
        <div className="card-header">
          <div className="user-info-section">
            <div className="user-avatar">
              <User className="avatar-icon" />
            </div>
            <div className="user-details">
              <h3 className="user-name">{experience.userName}</h3>
              <p className="post-date">{formatDate(experience.sharedAt)}</p>
            </div>
          </div>
          
          <div className="post-actions">
            {audioEnabled && (
              <button 
                onClick={handleReadAloud}
                className="read-aloud-button"
                title="Read story aloud"
              >
                <Volume2 className="voice-control-icon" />
              </button>
            )}
            
            {isOwner && (
              <>
                <button onClick={() => setShowEditModal(true)} className="edit-button" title="Edit post">
                  <Edit className="action-icon" />
                </button>
                <button onClick={() => setShowDeleteConfirm(true)} className="delete-button" title="Delete post">
                  <Trash2 className="action-icon" />
                </button>
              </>
            )}
          </div>
        </div>

        <div className="card-content">
          <h4 className="post-title">{experience.title}</h4>
          <p className="post-description">{safeDescription}</p>
        </div>

        {/* Facebook-style Engagement Bar */}
        <div className="engagement-bar">
          <div className="engagement-stats">
            {experience.likes > 0 && (
              <span className="likes-count">
                {experience.likes} {experience.likes === 1 ? 'like' : 'likes'}
              </span>
            )}
            {experience.comments > 0 && (
              <span className="comments-count">
                {experience.comments} {experience.comments === 1 ? 'comment' : 'comments'}
              </span>
            )}
          </div>
        </div>

        {/* Action Buttons */}
        <div className="action-buttons">
          <button
            onClick={handleLike}
            disabled={isLiking}
            className={`action-button like-button ${experience.liked ? 'liked' : ''}`}
          >
            <Heart className={`action-icon ${experience.liked ? 'filled' : ''}`} />
            <span>{experience.liked ? 'Liked' : 'Like'}</span>
          </button>
          
          <button
            onClick={() => setShowComments(!showComments)}
            className={`action-button comment-button ${showComments ? 'active' : ''}`}
          >
            <MessageCircle className="action-icon" />
            <span>Comment</span>
          </button>
        </div>

        {/* Comments Section */}
        {showComments && (
          <div className="comments-section">
            {/* Comment Input */}
            <div className="comment-input-container">
              <div className="comment-avatar">
                <User size={32} />
              </div>
              <div className="comment-input-wrapper">
                <input
                  type="text"
                  placeholder="Write a comment..."
                  value={newComment}
                  onChange={(e) => setNewComment(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleAddComment()}
                  className="comment-input"
                  disabled={isSubmittingComment}
                />
                <button
                  onClick={handleAddComment}
                  disabled={!newComment.trim() || isSubmittingComment}
                  className="comment-submit-button"
                >
                  {isSubmittingComment ? 'Posting...' : 'Post'}
                </button>
              </div>
            </div>

            {/* Comments List */}
            <div className="comments-list">
              {comments.length === 0 ? (
                <div className="no-comments">
                  <p>No comments yet. Be the first to comment!</p>
                </div>
              ) : (
                comments.map((comment) => (
                  <div key={comment.id} className="comment-item">
                    <div className="comment-avatar">
                      <User size={32} />
                    </div>
                    <div className="comment-content">
                      <div className="comment-header">
                        <span className="comment-author">{comment.displayName}</span>
                        <span className="comment-time">{formatDate(comment.timestamp)}</span>
                      </div>
                      <div className="comment-text">
                        {comment.content}
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        )}
      </div>

      {/* Edit and Delete Modals */}
      {showEditModal && (
        <PostFormModal
          editExperience={experience}
          onClose={() => setShowEditModal(false)}
          onSuccess={(forceAll) => {
            onEdit(forceAll);
            setShowEditModal(false);
          }}
          audioEnabled={audioEnabled}
          speakText={() => {}}
        />
      )}

      {showDeleteConfirm && (
        <div className="modal-overlay">
          <div className="delete-confirmation-modal">
            <h3 className="delete-confirmation-title">Delete Story?</h3>
            <p className="delete-confirmation-message">
              Are you sure you want to delete this story? This action cannot be undone.
            </p>
            <div className="delete-confirmation-actions">
              <button onClick={() => setShowDeleteConfirm(false)} className="cancel-delete-button">
                Cancel
              </button>
              <button onClick={handleDelete} className="confirm-delete-button">
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

// PostFormModal Component
function PostFormModal({ onClose, onSuccess, editExperience = null, audioEnabled, speakText }) {
  const [title, setTitle] = useState(editExperience?.title || "");
  const [description, setDescription] = useState(editExperience?.description || "");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const loggedInEmail = localStorage.getItem("loggedInEmail") || "anonymous@example.com";
  const emailKey = normalizeEmail(loggedInEmail);

  const handleSubmit = async () => {
    if (!title.trim() || !description.trim()) {
      setError("Please fill in both title and description");
      return;
    }
    setLoading(true);
    setError("");
    try {
      const experience = new ShareExperienceEntity(
        editExperience ? editExperience.id : null,
        emailKey,
        title.trim(),
        description.trim(),
        editExperience ? editExperience.sharedAt : new Date().toISOString()
      );
      if (editExperience) {
        await ShareExperienceController.updateExperience(experience);
        onSuccess(true);
      } else {
        await ShareExperienceController.addExperience(experience);
        onSuccess();
      }
      onClose();
    } catch (err) {
      console.error("Error saving experience:", err);
      setError("Failed to save your story. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="post-form-modal">
        <div className="modal-header">
          <h2 className="modal-title">
            {editExperience ? "Edit Your Story" : "Share Your Story"}
          </h2>
          <button onClick={onClose} className="modal-close-button">
            <X className="modal-close-icon" />
          </button>
        </div>
        <div className="modal-form">
          <div className="form-field">
            <label className="form-label">Story Title</label>
            <input
              type="text"
              placeholder="What's your story about?"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              disabled={loading}
              className="form-input"
            />
          </div>
          <div className="form-field">
            <label className="form-label">Your Story</label>
            <textarea
              placeholder="Share your experience..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={6}
              disabled={loading}
              className="form-textarea"
            />
          </div>
          {error && <div className="error-message"><p>{error}</p></div>}
          <div className="form-actions">
            <button onClick={onClose} disabled={loading} className="cancel-button">
              Cancel
            </button>
            <button
              onClick={handleSubmit}
              disabled={loading || (!title.trim() || !description.trim())}
              className={`submit-button ${
                loading || (!title.trim() || !description.trim()) ? 'submit-button-disabled' : ''
              }`}
            >
              {loading ? "Sharing..." : editExperience ? "Update Story" : "Share Story"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// Main ShareExperiencePage Component
export default function ShareExperiencePage() {
  const [experiences, setExperiences] = useState([]);
  const [filteredExperiences, setFilteredExperiences] = useState([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [showPostForm, setShowPostForm] = useState(false);
  const [currentView, setCurrentView] = useState("newsfeed");
  const [accounts, setAccounts] = useState({});
  const [showMessaging, setShowMessaging] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [conversations, setConversations] = useState([]);
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showFriends, setShowFriends] = useState(false);
  
  // Voice control states
  const [audioEnabled, setAudioEnabled] = useState(true);
  const [isSpeaking, setIsSpeaking] = useState(false);
  
  const loggedInEmail = localStorage.getItem("loggedInEmail") || "anonymous@example.com";
  const currentUserKey = normalizeEmail(loggedInEmail);

  useEffect(() => {
    fetchAccounts();
    fetchExperiences();
    fetchNotifications();
    if (showMessaging) {
      fetchConversations();
    }
  }, [showMessaging]);

  useEffect(() => {
    filterExperiences();
  }, [searchQuery, experiences, currentView]);
  
  // Add this useEffect to your ShareExperiencePage component
  useEffect(() => {
    // Check if there's a URL parameter to open messaging
    const urlParams = new URLSearchParams(window.location.search);
    const openMessaging = urlParams.get('openMessaging');
    
    if (openMessaging === 'true') {
      setShowMessaging(true);
    }
  }, []);

  const fetchAccounts = async () => {
    try {
      const accountsData = await ShareExperienceController.getAccounts();
      setAccounts(accountsData || {});
    } catch (error) {
      console.error("Error fetching accounts:", error);
    }
  };

  const fetchExperiences = (forceAll = false) => {
    const userKey = (currentView === "myposts" && !forceAll) ? currentUserKey : null;
    ShareExperienceController.getUserExperiences(userKey, (allExperiences) => {
      const experiencesWithNames = allExperiences.map(exp => ({
        ...exp,
        userName: getUserDisplayName(exp.user, accounts),
        likes: exp.likes || 0,
        comments: exp.comments || 0,
        liked: false
      }));
      setExperiences(experiencesWithNames);
    });
  };

  const fetchNotifications = () => {
    ShareExperienceController.getUserNotifications(currentUserKey, (notificationList) => {
      setNotifications(notificationList);
    });

    ShareExperienceController.getUnreadNotificationCount(currentUserKey, (count) => {
      setUnreadCount(count);
    });
  };

  const filterExperiences = () => {
    let filtered = experiences;
    if (currentView === "myposts") {
      filtered = experiences.filter(exp =>
        exp.user === currentUserKey ||
        exp.user === currentUserKey.replace(/_/g, "_x")
      );
    }
    if (searchQuery.trim()) {
      filtered = filtered.filter(exp =>
        exp.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        exp.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
        exp.userName.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }
    setFilteredExperiences(filtered);
  };

  const fetchConversations = () => {
    ShareExperienceController.getUserConversations(currentUserKey, (conversationList) => {
      setConversations(conversationList);
    });
  };

  // Text-to-speech function
  const speakText = (text) => {
    if ('speechSynthesis' in window && audioEnabled) {
      window.speechSynthesis.cancel();
      
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = "en-US";
      utterance.rate = 0.9;
      utterance.pitch = 1;
      utterance.volume = 1;
      
      utterance.onstart = () => setIsSpeaking(true);
      utterance.onend = () => setIsSpeaking(false);
      utterance.onerror = () => setIsSpeaking(false);
      
      window.speechSynthesis.speak(utterance);
    }
  };

  const toggleAudio = () => {
    if (isSpeaking) {
      window.speechSynthesis.cancel();
      setIsSpeaking(false);
    }
    setAudioEnabled(!audioEnabled);
  };

  const readExperienceAloud = (experience) => {
    const textToRead = `${experience.title}. ${experience.description}. Shared by ${experience.userName}.`;
    speakText(textToRead);
  };

  // FIXED handleStartChat function
  const handleStartChat = (userKey, userName) => {
    const normalizedUserKey = normalizeEmail(userKey);
    
    // Check if user can chat based on user types and relationships
    const currentUserAccount = accounts[currentUserKey];
    const targetUserAccount = accounts[normalizedUserKey];
    
    let canChat = false;
    
    if (currentUserAccount && targetUserAccount) {
      // Elderly users can chat with:
      // - Their caregivers (automatically linked via elderlyId/elderlyIds)
      // - Other elderly friends
      if (currentUserAccount.userType === 'elderly') {
        if (targetUserAccount.userType === 'caregiver') {
          // Check if this caregiver is assigned to the current elderly
          const isCaregiverAssigned = 
            (targetUserAccount.elderlyId && 
             (normalizeEmail(targetUserAccount.elderlyId) === currentUserKey || 
              targetUserAccount.elderlyId === currentUserAccount.email)) ||
            (targetUserAccount.elderlyIds && 
             Array.isArray(targetUserAccount.elderlyIds) && 
             targetUserAccount.elderlyIds.some(id => 
               normalizeEmail(id) === currentUserKey || id === currentUserAccount.email
             ));
          
          if (isCaregiverAssigned) {
            canChat = true; // Can chat with their caregiver
          }
        } else if (targetUserAccount.userType === 'elderly') {
          // For elderly to elderly, we need to check friendship status
          // For now, let's assume they can chat if they found each other through friends panel
          canChat = true;
        }
      }
      // Caregivers can chat with:
      // - Their assigned elderly
      // - Other caregivers of the same elderly
      else if (currentUserAccount.userType === 'caregiver') {
        if (targetUserAccount.userType === 'elderly') {
          // Check if this elderly is assigned to the current caregiver
          const isElderlyAssigned = 
            (currentUserAccount.elderlyId && 
             (normalizeEmail(currentUserAccount.elderlyId) === normalizedUserKey || 
              currentUserAccount.elderlyId === targetUserAccount.email)) ||
            (currentUserAccount.elderlyIds && 
             Array.isArray(currentUserAccount.elderlyIds) && 
             currentUserAccount.elderlyIds.some(id => 
               normalizeEmail(id) === normalizedUserKey || id === targetUserAccount.email
             ));
          
          if (isElderlyAssigned) {
            canChat = true; // Can chat with their assigned elderly
          }
        } else if (targetUserAccount.userType === 'caregiver') {
          // Check if they share the same elderly assignment
          const currentCaregiverElders = new Set([
            ...(currentUserAccount.elderlyId ? [normalizeEmail(currentUserAccount.elderlyId)] : []),
            ...(currentUserAccount.elderlyIds ? currentUserAccount.elderlyIds.map(normalizeEmail) : [])
          ]);
          
          const targetCaregiverElders = new Set([
            ...(targetUserAccount.elderlyId ? [normalizeEmail(targetUserAccount.elderlyId)] : []),
            ...(targetUserAccount.elderlyIds ? targetUserAccount.elderlyIds.map(normalizeEmail) : [])
          ]);
          
          // Check if they have any elderly in common
          const sharedElders = [...currentCaregiverElders].filter(elder => targetCaregiverElders.has(elder));
          canChat = sharedElders.length > 0;
        }
      }
      // Admins can chat with everyone
      else if (currentUserAccount.userType === 'admin') {
        canChat = true;
      }
    }
    
    if (canChat) {
      setSelectedUser({ key: normalizedUserKey, name: userName });
      setShowMessaging(true);
      fetchConversations();
      setShowFriends(false);
    } else {
      alert('You cannot start a chat with this user. Please check your connection or add them as a friend first.');
    }
  };

  // In ShareExperiencePage component, update the handleLike function:
const handleLike = async (id, experienceUser, currentLikes, isCurrentlyLiked) => {
  try {
    const result = await ShareExperienceController.toggleLike(id, currentUserKey, currentLikes, isCurrentlyLiked);
    
    // Update local state
    const updatedExperiences = experiences.map(exp => {
      if (exp.id === id) {
        // Send notification if liking (not unliking)
        if (!isCurrentlyLiked && experienceUser !== currentUserKey) {
          const notification = new NotificationEntity(
            null,
            experienceUser,
            currentUserKey,
            'like',
            'New Like',
            `${getUserDisplayName(currentUserKey, accounts)} liked your story`,
            id,
            new Date().toISOString()
          );
          ShareExperienceController.sendNotification(notification);
        }
        
        return {
          ...exp,
          liked: result.liked,
          likes: result.newLikes
        };
      }
      return exp;
    });
    setExperiences(updatedExperiences);
  } catch (error) {
    console.error("Error toggling like:", error);
    throw error;
  }
};

  const handleMarkAllAsRead = () => {
    ShareExperienceController.markAllNotificationsAsRead(currentUserKey);
    fetchNotifications();
  };

  const handleNotificationClick = (notification) => {
    ShareExperienceController.markNotificationAsRead(notification.id);
    
    switch (notification.type) {
      case 'message':
        setShowMessaging(true);
        setSelectedUser({ key: notification.fromUser, name: getUserDisplayName(notification.fromUser, accounts) });
        setShowNotifications(false);
        break;
      case 'like':
        console.log('Liked post:', notification.relatedId);
        break;
      default:
        break;
    }
    
    fetchNotifications();
  };

  const handleDeleteNotification = async (notificationId, e) => {
    e.stopPropagation();
    try {
      await ShareExperienceController.deleteNotification(notificationId);
      fetchNotifications();
    } catch (error) {
      console.error("Error deleting notification:", error);
    }
  };

  // Handle new message notification
  const handleNewMessage = () => {
    // Refresh notifications to show the new message notification
    fetchNotifications();
  };

  const getViewTitle = () => {
    if (currentView === "myposts") {
      return searchQuery ? `My Posts matching "${searchQuery}"` : "My Posts";
    }
    return searchQuery ? `Newsfeed matching "${searchQuery}"` : "Community Stories";
  };

  const getEmptyStateMessage = () => {
    if (currentView === "myposts") {
      return searchQuery 
        ? "No posts found matching your search in your stories."
        : "You haven't shared any stories yet. Share your first story!";
    }
    return searchQuery 
      ? "No community stories found matching your search."
      : "No stories shared in the community yet. Be the first to share!";
  };

  return (
    <div>
      <div className="experience-sharing-app">
        {/* Header */}
        <header className="app-header">
          <div className="header-container">
            <div className="brand-section">
              <div className="brand-logo">
                <Heart className="brand-icon" />
              </div>
              <h1 className="brand-title">Share Your Journey</h1>
            </div>
            
            {/* Search Bar */}
            <div className="search-section">
              <div className="search-input-wrapper">
                <Search className="search-icon" />
                <input
                  type="text"
                  placeholder="Search experiences..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="search-input"
                />
              </div>
            </div>

            <div className="header-actions">
              {/* Voice Controls */}
              <div className="voice-controls">
                <button 
                  onClick={toggleAudio}
                  className={`audio-toggle ${isSpeaking ? 'speaking' : ''}`}
                  aria-label={audioEnabled ? "Mute audio" : "Enable audio"}
                  title={audioEnabled ? "Mute audio" : "Enable audio"}
                >
                  {audioEnabled ? <VolumeUpIcon /> : <VolumeOffIcon />}
                </button>
              </div>

              <button style={{marginLeft: "60px"}}
                onClick={() => setShowNotifications(true)}
                className="notifications-button"
                title="Notifications"
              >
                {unreadCount > 0 ? (
                  <BellRing className="notifications-icon" />
                ) : (
                  <Bell className="notifications-icon" />
                )}
                {unreadCount > 0 && (
                  <span className="notification-badge">{unreadCount > 99 ? '99+' : unreadCount}</span>
                )}
              </button>
              <button
                onClick={() => setShowMessaging(true)}
                className="messaging-button"
                title="Messages"
              >
                <MessageSquare className="messaging-icon" />
              </button>
              <button
                onClick={() => setShowPostForm(true)}
                className="share-story-button"
              >
                Share Story
              </button>
            </div>
          </div>
        </header>

        {/* Navigation Tabs */}
        <div className="navigation-tabs" style={{marginTop: "-30px"}}>
          <div className="tabs-container">
            <button
              onClick={() => setCurrentView("newsfeed")}
              className={`nav-tab ${currentView === "newsfeed" ? "nav-tab-active" : ""}`}
            >
              <Users className="nav-tab-icon" />
              <span className="nav-tab-text">Newsfeed</span>
            </button>
            <button
              onClick={() => setCurrentView("myposts")}
              className={`nav-tab ${currentView === "myposts" ? "nav-tab-active" : ""}`}
            >
              <UserCheck className="nav-tab-icon" />
              <span className="nav-tab-text">My Posts</span>
            </button>
          </div>
        </div>

        {/* Voice Instructions */}
        {!searchQuery && filteredExperiences.length > 0 && (
          <div className="voice-instructions-banner">
            
          </div>
        )}

        {/* Main Content */}
        <main className="main-content">
          {showPostForm && (
            <PostFormModal
              onClose={() => setShowPostForm(false)}
              onSuccess={fetchExperiences}
              audioEnabled={audioEnabled}
              speakText={speakText}
            />
          )}

          {showFriends && (
            <div className="friends-overlay">
              <FriendsPanel
                currentUserKey={currentUserKey}
                onClose={() => setShowFriends(false)}
                onStartChat={handleStartChat}
                accounts={accounts}
              />
            </div>
          )}

          {showMessaging && (
            <MessagingPanel
              currentUserKey={currentUserKey}
              selectedUser={selectedUser}
              onClose={() => {
                setShowMessaging(false);
                setSelectedUser(null);
              }}
              onUserSelect={setSelectedUser}
              conversations={conversations}
              accounts={accounts}
              audioEnabled={audioEnabled}
              speakText={speakText}
              onNewMessage={handleNewMessage}
            />
          )}

          {showNotifications && (
            <NotificationsPanel
              notifications={notifications}
              onClose={() => setShowNotifications(false)}
              onNotificationClick={handleNotificationClick}
              onMarkAllAsRead={handleMarkAllAsRead}
              onDeleteNotification={handleDeleteNotification}
              accounts={accounts}
            />
          )}

          <div className="content-header">
            <h2 className="view-title">{getViewTitle()}</h2>
            {filteredExperiences.length > 0 && (
              <p className="results-count">
                {filteredExperiences.length} story{filteredExperiences.length !== 1 ? 's' : ''} found
              </p>
            )}
          </div>

          <div className="experience-feed">
            {filteredExperiences.length === 0 ? (
              <div className="empty-state">
                <Heart className="empty-state-icon" />
                <h3 className="empty-state-title">
                  {currentView === "myposts" && !searchQuery ? "No stories yet" : "No stories found"}
                </h3>
                <p className="empty-state-message">{getEmptyStateMessage()}</p>
                {currentView === "myposts" && !searchQuery && (
                  <button
                    onClick={() => setShowPostForm(true)}
                    className="share-first-story-button"
                  >
                    Share Your First Story
                  </button>
                )}
              </div>
            ) : (
              filteredExperiences.map((experience) => (
                // In the main component's render, update the ExperienceCard usage:
              <ExperienceCard
                key={experience.id}
                experience={experience}
                currentUserKey={currentUserKey}
                onLike={handleLike}
                onEdit={() => fetchExperiences(true)}
                onDelete={fetchExperiences}
                onStartChat={handleStartChat}
                onReadAloud={readExperienceAloud}
                accounts={accounts}
                audioEnabled={audioEnabled}
              />
              ))
            )}
          </div>
          <br/><br/><br/>
        </main>
      </div>
      <Footer />
    </div>
  );
}

class Messenger {
  constructor() {
    this.isOpen = false;
    this.messages = [];
    this.unreadCount = 0;
    this.lastMessageCount = 0;
    this.eventSource = null;
    this.typingTimer = null;
    this.isTyping = false;
    this.typingUsers = new Set();
    this.currentUserId = null;
    this.currentUsername = null;
    this.currentUserRole = null;
    this.lastReadMessageId = null;
    this.isDragging = false;
    this.dragOffset = { x: 0, y: 0 };
    this.init();
  }

  init() {
    this.createMessengerHTML();
    this.attachEventListeners();
    this.loadCurrentUser();
    this.connectToMessageStream();
    this.startNotificationCheck();
    this.loadLastReadMessage();
  }

  async loadCurrentUser() {
    try {
      const response = await fetch('/auth/session', { credentials: 'include' });
      const sessionData = await response.json();
      this.currentUserId = sessionData.id;
      this.currentUsername = sessionData.username;
      this.currentUserRole = sessionData.role;
    } catch (error) {
      console.error('Error loading user session:', error);
    }
  }

  loadLastReadMessage() {
    this.lastReadMessageId = localStorage.getItem(`lastRead_${this.currentUserId}`) || null;
  }

  saveLastReadMessage() {
    if (this.messages.length > 0) {
      const lastMessage = this.messages[this.messages.length - 1];
      this.lastReadMessageId = lastMessage.id;
      localStorage.setItem(`lastRead_${this.currentUserId}`, this.lastReadMessageId);
    }
  }

  connectToMessageStream() {
    if (this.eventSource) {
      this.eventSource.close();
    }

    this.eventSource = new EventSource('/messages/stream');
    
    this.eventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        this.handleRealtimeMessage(data);
      } catch (error) {
        console.error('Error parsing SSE message:', error);
      }
    };

    this.eventSource.onerror = (error) => {
      console.error('SSE connection error:', error);
      setTimeout(() => {
        if (!this.eventSource || this.eventSource.readyState === EventSource.CLOSED) {
          this.connectToMessageStream();
        }
      }, 5000);
    };
  }

  handleRealtimeMessage(data) {
    switch (data.type) {
      case 'connected':
        console.log('Connected to message stream');
        break;
      case 'new_message':
        this.addMessage(data.data);
        if (!this.isOpen && data.data.user_id !== this.currentUserId) {
          this.incrementUnreadCount();
          this.showNotification(data.data);
          this.updateChatButtonPreview(data.data);
        }
        break;
      case 'typing':
        this.handleTypingIndicator(data.data);
        break;
      case 'message_deleted':
        this.removeMessage(data.data.messageId);
        break;
    }
  }

  updateChatButtonPreview(message) {
    const chatButton = document.getElementById('chat-button');
    const preview = chatButton.querySelector('.message-preview');
    
    if (preview) {
      preview.textContent = `${message.username}: ${message.message.substring(0, 30)}${message.message.length > 30 ? '...' : ''}`;
      preview.style.display = 'block';
    }
  }

  createMessengerHTML() {
    const messengerHTML = `
      <div id="chat-button" class="chat-button">
        💬
        <span id="notification-badge" class="notification-badge" style="display: none;">0</span>
        <div class="message-preview" style="display: none;"></div>
      </div>
      
      <div id="messenger-popup" class="messenger-popup" style="display: none;">
        <div class="messenger-header" id="messenger-header">
          <div class="header-content">
            <span class="messenger-title">🔥 Emergency Chat</span>
            <div class="online-status">
              <span class="status-dot"></span>
              <span id="online-count">0 online</span>
            </div>
          </div>
          <div class="header-actions">
            <button id="minimize-messenger" class="header-button" title="Minimize">−</button>
            <button id="close-messenger" class="header-button" title="Close">✕</button>
          </div>
        </div>
        
        <div id="messages-container" class="messages-container">
          <div class="empty-state" id="empty-state">
            <div class="empty-icon">💬</div>
            <h3>Welcome to Emergency Chat</h3>
            <p>No messages yet. Start the conversation to coordinate emergency responses!</p>
            <div class="empty-features">
              <div class="feature">
                <span>🚨</span>
                <span>Real-time alerts</span>
              </div>
              <div class="feature">
                <span>👥</span>
                <span>Team coordination</span>
              </div>
              <div class="feature">
                <span>📱</span>
                <span>Instant notifications</span>
              </div>
            </div>
          </div>
        </div>
        
        <div id="typing-indicator" class="typing-indicator" style="display: none;">
          <span class="typing-dots">
            <span></span><span></span><span></span>
          </span>
          <span id="typing-text">Someone is typing...</span>
        </div>
        
        <div class="message-input-container">
          <input type="text" id="message-input" placeholder="Type your emergency message..." maxlength="1000">
          <button id="send-message" class="send-button">➤</button>
        </div>
      </div>
    `;
    
    document.body.insertAdjacentHTML('beforeend', messengerHTML);
    
    // Add enhanced CSS with new features
    const style = document.createElement('style');
    style.textContent = `
      .chat-button {
        position: fixed;
        bottom: 20px;
        right: 20px;
        width: 60px;
        height: 60px;
        background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        box-shadow: 0 4px 12px rgba(220, 38, 38, 0.4);
        font-size: 24px;
        color: white;
        transition: all 0.3s ease;
        z-index: 1000;
        border: none;
        animation: pulse 2s infinite;
        overflow: visible;
      }
      
      .message-preview {
        position: absolute;
        bottom: 70px;
        right: 0;
        min-width: 200px;
        max-width: 250px;
        background: white;
        padding: 8px 12px;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        font-size: 12px;
        color: #374151;
        border: 1px solid #e5e7eb;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        animation: slideUp 0.3s ease;
      }
      
      .message-preview::after {
        content: '';
        position: absolute;
        bottom: -5px;
        right: 20px;
        width: 10px;
        height: 10px;
        background: white;
        border-right: 1px solid #e5e7eb;
        border-bottom: 1px solid #e5e7eb;
        transform: rotate(45deg);
      }
      
      @keyframes slideUp {
        from { transform: translateY(10px); opacity: 0; }
        to { transform: translateY(0); opacity: 1; }
      }
      
      @keyframes pulse {
        0%, 100% { transform: scale(1); }
        50% { transform: scale(1.05); }
      }
      
      .chat-button:hover {
        transform: scale(1.1);
        box-shadow: 0 6px 20px rgba(220, 38, 38, 0.6);
      }
      
      .notification-badge {
        position: absolute;
        top: -8px;
        right: -8px;
        background: #ef4444;
        color: white;
        border-radius: 50%;
        width: 24px;
        height: 24px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 12px;
        font-weight: bold;
        border: 2px solid white;
        animation: bounce 0.5s ease;
      }
      
      @keyframes bounce {
        0%, 100% { transform: scale(1); }
        50% { transform: scale(1.2); }
      }
      
      .messenger-popup {
        position: fixed;
        bottom: 100px;
        right: 20px;
        width: 380px;
        height: 500px;
        background: white;
        border-radius: 16px;
        box-shadow: 0 10px 40px rgba(0, 0, 0, 0.15);
        display: flex;
        flex-direction: column;
        z-index: 1001;
        border: 1px solid #e5e7eb;
        overflow: hidden;
        animation: slideIn 0.3s ease;
        user-select: none;
      }
      
      .messenger-popup.minimized {
        height: 60px;
        overflow: hidden;
      }
      
      .messenger-popup.dragging {
        transition: none;
      }
      
      @keyframes slideIn {
        from { transform: translateY(20px); opacity: 0; }
        to { transform: translateY(0); opacity: 1; }
      }
      
      .messenger-header {
        background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
        color: white;
        padding: 16px;
        display: flex;
        justify-content: space-between;
        align-items: center;
        cursor: move;
      }
      
      .header-content {
        display: flex;
        flex-direction: column;
        gap: 4px;
      }
      
      .messenger-title {
        font-weight: 600;
        font-size: 16px;
      }
      
      .online-status {
        display: flex;
        align-items: center;
        gap: 6px;
        font-size: 12px;
        opacity: 0.9;
      }
      
      .status-dot {
        width: 8px;
        height: 8px;
        background: #10b981;
        border-radius: 50%;
        animation: pulse 2s infinite;
      }
      
      .header-actions {
        display: flex;
        gap: 8px;
      }
      
      .header-button {
        background: none;
        border: none;
        color: white;
        font-size: 16px;
        cursor: pointer;
        opacity: 0.8;
        transition: opacity 0.2s;
        padding: 4px 8px;
        border-radius: 4px;
      }
      
      .header-button:hover {
        opacity: 1;
        background: rgba(255, 255, 255, 0.1);
      }
      
      .messages-container {
        flex: 1;
        overflow-y: auto;
        padding: 16px;
        background: #f9fafb;
      }
      
      .empty-state {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        height: 100%;
        text-align: center;
        color: #6b7280;
      }
      
      .empty-icon {
        font-size: 48px;
        margin-bottom: 16px;
        opacity: 0.5;
      }
      
      .empty-state h3 {
        color: #374151;
        margin-bottom: 8px;
        font-size: 18px;
      }
      
      .empty-state p {
        margin-bottom: 24px;
        line-height: 1.5;
      }
      
      .empty-features {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      
      .feature {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 8px 16px;
        background: white;
        border-radius: 8px;
        border: 1px solid #e5e7eb;
      }
      
      .feature span:first-child {
        font-size: 20px;
      }
      
      .loading-messages {
        text-align: center;
        color: #6b7280;
        font-style: italic;
        padding: 20px;
      }
      
      .message {
        margin-bottom: 12px;
        padding: 10px 12px;
        border-radius: 12px;
        max-width: 85%;
        word-wrap: break-word;
        position: relative;
        animation: messageSlideIn 0.3s ease;
      }
      
      .message.unread {
        border-left: 3px solid #dc2626;
      }
      
      .message.last-read::after {
        content: 'Last read';
        position: absolute;
        right: -60px;
        top: 50%;
        transform: translateY(-50%);
        background: #dc2626;
        color: white;
        padding: 2px 6px;
        border-radius: 4px;
        font-size: 10px;
        white-space: nowrap;
      }
      
      @keyframes messageSlideIn {
        from { transform: translateY(10px); opacity: 0; }
        to { transform: translateY(0); opacity: 1; }
      }
      
      .message.own {
        background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
        color: white;
        margin-left: auto;
        border-bottom-right-radius: 4px;
      }
      
      .message.other {
        background: white;
        color: #1f2937;
        margin-right: auto;
        border: 1px solid #e5e7eb;
        border-bottom-left-radius: 4px;
      }
      
      .message.system {
        background: #fef3c7;
        color: #92400e;
        border: 1px solid #f59e0b;
        text-align: center;
        margin: 8px auto;
        font-style: italic;
      }
      
      .message-header {
        font-size: 11px;
        opacity: 0.8;
        margin-bottom: 4px;
        font-weight: 600;
      }
      
      .message-content {
        line-height: 1.4;
      }
      
      .message-time {
        font-size: 10px;
        opacity: 0.7;
        margin-top: 4px;
      }
      
      .message-actions {
        position: absolute;
        top: 4px;
        right: 4px;
        opacity: 0;
        transition: opacity 0.2s;
      }
      
      .message:hover .message-actions {
        opacity: 1;
      }
      
      .delete-message {
        background: rgba(239, 68, 68, 0.1);
        border: none;
        color: #ef4444;
        border-radius: 4px;
        padding: 2px 6px;
        cursor: pointer;
        font-size: 12px;
      }
      
      .typing-indicator {
        padding: 8px 16px;
        background: #f3f4f6;
        border-top: 1px solid #e5e7eb;
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 12px;
        color: #6b7280;
      }
      
      .typing-dots {
        display: flex;
        gap: 2px;
      }
      
      .typing-dots span {
        width: 4px;
        height: 4px;
        background: #9ca3af;
        border-radius: 50%;
        animation: typing 1.4s infinite ease-in-out;
      }
      
      .typing-dots span:nth-child(1) { animation-delay: -0.32s; }
      .typing-dots span:nth-child(2) { animation-delay: -0.16s; }
      
      @keyframes typing {
        0%, 80%, 100% { transform: scale(0.8); opacity: 0.5; }
        40% { transform: scale(1); opacity: 1; }
      }
      
      .message-input-container {
        display: flex;
        padding: 16px;
        background: white;
        border-top: 1px solid #e5e7eb;
        gap: 8px;
      }
      
      #message-input {
        flex: 1;
        border: 2px solid #e5e7eb;
        border-radius: 8px;
        padding: 10px 12px;
        font-size: 14px;
        outline: none;
        transition: border-color 0.2s;
      }
      
      #message-input:focus {
        border-color: #dc2626;
      }
      
      .send-button {
        background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
        color: white;
        border: none;
        border-radius: 8px;
        padding: 10px 16px;
        cursor: pointer;
        font-size: 16px;
        transition: all 0.2s;
      }
      
      .send-button:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(220, 38, 38, 0.3);
      }
      
      .send-button:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }
      
      @media (max-width: 480px) {
        .messenger-popup {
          width: calc(100vw - 20px);
          right: 10px;
          bottom: 90px;
        }
      }
    `;
    document.head.appendChild(style);
  }

  attachEventListeners() {
    const chatButton = document.getElementById('chat-button');
    const closeButton = document.getElementById('close-messenger');
    const minimizeButton = document.getElementById('minimize-messenger');
    const sendButton = document.getElementById('send-message');
    const messageInput = document.getElementById('message-input');
    const header = document.getElementById('messenger-header');

    chatButton.addEventListener('click', () => this.toggleMessenger());
    closeButton.addEventListener('click', () => this.closeMessenger());
    minimizeButton.addEventListener('click', () => this.toggleMinimize());
    sendButton.addEventListener('click', () => this.sendMessage());
    
    messageInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') {
        this.sendMessage();
      }
    });

    messageInput.addEventListener('input', () => {
      this.handleTyping();
    });

    // Drag functionality
    header.addEventListener('mousedown', (e) => this.startDrag(e));
    document.addEventListener('mousemove', (e) => this.drag(e));
    document.addEventListener('mouseup', () => this.stopDrag());

    // Touch events for mobile
    header.addEventListener('touchstart', (e) => this.startDrag(e.touches[0]));
    document.addEventListener('touchmove', (e) => {
      if (this.isDragging) {
        e.preventDefault();
        this.drag(e.touches[0]);
      }
    });
    document.addEventListener('touchend', () => this.stopDrag());

    window.addEventListener('resize', () => {
      if (this.isOpen) {
        this.adjustPopupPosition();
      }
    });
  }

  startDrag(e) {
    this.isDragging = true;
    const popup = document.getElementById('messenger-popup');
    const rect = popup.getBoundingClientRect();
    
    this.dragOffset.x = e.clientX - rect.left;
    this.dragOffset.y = e.clientY - rect.top;
    
    popup.classList.add('dragging');
  }

  drag(e) {
    if (!this.isDragging) return;
    
    const popup = document.getElementById('messenger-popup');
    const x = e.clientX - this.dragOffset.x;
    const y = e.clientY - this.dragOffset.y;
    
    // Keep popup within viewport bounds
    const maxX = window.innerWidth - popup.offsetWidth;
    const maxY = window.innerHeight - popup.offsetHeight;
    
    const boundedX = Math.max(0, Math.min(x, maxX));
    const boundedY = Math.max(0, Math.min(y, maxY));
    
    popup.style.left = boundedX + 'px';
    popup.style.top = boundedY + 'px';
    popup.style.right = 'auto';
    popup.style.bottom = 'auto';
  }

  stopDrag() {
    if (!this.isDragging) return;
    
    this.isDragging = false;
    const popup = document.getElementById('messenger-popup');
    popup.classList.remove('dragging');
  }

  toggleMinimize() {
    const popup = document.getElementById('messenger-popup');
    popup.classList.toggle('minimized');
  }

  handleTyping() {
    if (!this.isTyping) {
      this.isTyping = true;
      this.sendTypingIndicator(true);
    }

    clearTimeout(this.typingTimer);
    this.typingTimer = setTimeout(() => {
      this.isTyping = false;
      this.sendTypingIndicator(false);
    }, 1000);
  }

  async sendTypingIndicator(isTyping) {
    try {
      await fetch('/messages/typing', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({ isTyping })
      });
    } catch (error) {
      console.error('Error sending typing indicator:', error);
    }
  }

  handleTypingIndicator(data) {
    const { userId, username, isTyping } = data;
    
    if (isTyping) {
      this.typingUsers.add(username);
    } else {
      this.typingUsers.delete(username);
    }

    this.updateTypingDisplay();
  }

  updateTypingDisplay() {
    const typingIndicator = document.getElementById('typing-indicator');
    const typingText = document.getElementById('typing-text');
    
    if (this.typingUsers.size > 0) {
      const users = Array.from(this.typingUsers);
      let text;
      if (users.length === 1) {
        text = `${users[0]} is typing...`;
      } else if (users.length === 2) {
        text = `${users[0]} and ${users[1]} are typing...`;
      } else {
        text = `${users.length} people are typing...`;
      }
      
      typingText.textContent = text;
      typingIndicator.style.display = 'flex';
    } else {
      typingIndicator.style.display = 'none';
    }
  }

  adjustPopupPosition() {
    const popup = document.getElementById('messenger-popup');
    const viewportHeight = window.innerHeight;
    const viewportWidth = window.innerWidth;
    
    if (viewportWidth <= 480) {
      popup.style.width = 'calc(100vw - 20px)';
      popup.style.right = '10px';
    } else {
      popup.style.width = '380px';
      popup.style.right = '20px';
    }
  }

  toggleMessenger() {
    const popup = document.getElementById('messenger-popup');
    if (this.isOpen) {
      this.closeMessenger();
    } else {
      popup.style.display = 'flex';
      this.isOpen = true;
      this.loadMessages();
      this.loadOnlineCount();
      document.getElementById('message-input').focus();
      
      // Clear notifications and preview when opening
      this.unreadCount = 0;
      this.lastMessageCount = this.messages.length;
      const badge = document.getElementById('notification-badge');
      const preview = document.querySelector('.message-preview');
      if (badge) badge.style.display = 'none';
      if (preview) preview.style.display = 'none';
      
      this.adjustPopupPosition();
      this.saveLastReadMessage();
    }
  }

  closeMessenger() {
    const popup = document.getElementById('messenger-popup');
    popup.style.display = 'none';
    this.isOpen = false;
    this.saveLastReadMessage();
  }

  async loadMessages() {
    try {
      const response = await fetch('/messages?limit=50', { credentials: 'include' });
      const messages = await response.json();
      this.messages = messages;
      this.renderMessages();
      this.scrollToBottom();
    } catch (error) {
      console.error('Error loading messages:', error);
      this.showError('Failed to load messages');
    }
  }

  async loadOnlineCount() {
    try {
      const response = await fetch('/messages/online', { credentials: 'include' });
      const data = await response.json();
      document.getElementById('online-count').textContent = `${data.count} online`;
    } catch (error) {
      console.error('Error loading online count:', error);
    }
  }

  renderMessages() {
    const container = document.getElementById('messages-container');
    const emptyState = document.getElementById('empty-state');
    
    if (this.messages.length === 0) {
      emptyState.style.display = 'flex';
      return;
    }

    emptyState.style.display = 'none';
    container.innerHTML = this.messages.map(msg => this.createMessageHTML(msg)).join('');
  }

  createMessageHTML(msg) {
    const time = new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const isOwn = msg.is_own_message;
    const messageClass = msg.message_type === 'system' ? 'system' : (isOwn ? 'own' : 'other');
    
    // Check if this is the last read message or unread
    const isLastRead = this.lastReadMessageId && msg.id == this.lastReadMessageId;
    const isUnread = this.lastReadMessageId && msg.id > this.lastReadMessageId && !isOwn;
    
    const additionalClasses = [];
    if (isLastRead) additionalClasses.push('last-read');
    if (isUnread) additionalClasses.push('unread');
    
    const canDelete = isOwn || (this.currentUserRole === 'admin');
    const deleteButton = canDelete ? `
      <div class="message-actions">
        <button class="delete-message" onclick="messenger.deleteMessage(${msg.id})" title="Delete message">🗑️</button>
      </div>
    ` : '';
    
    return `
      <div class="message ${messageClass} ${additionalClasses.join(' ')}" data-message-id="${msg.id}">
        ${!isOwn && msg.message_type !== 'system' ? `<div class="message-header">${msg.username} ${msg.role === 'admin' ? '👑' : '🚒'}</div>` : ''}
        <div class="message-content">${this.formatMessage(msg.message)}</div>
        <div class="message-time">${time}</div>
        ${deleteButton}
      </div>
    `;
  }

  formatMessage(message) {
    const urlRegex = /(https?:\/\/[^\s]+)/g;
    return message.replace(urlRegex, '<a href="$1" target="_blank" style="color: inherit; text-decoration: underline;">$1</a>');
  }

  addMessage(message) {
    this.messages.push(message);
    
    if (this.isOpen) {
      const container = document.getElementById('messages-container');
      const emptyState = document.getElementById('empty-state');
      
      if (emptyState.style.display !== 'none') {
        emptyState.style.display = 'none';
      }
      
      const messageHTML = this.createMessageHTML(message);
      container.insertAdjacentHTML('beforeend', messageHTML);
      this.scrollToBottom();
    }
  }

  removeMessage(messageId) {
    this.messages = this.messages.filter(msg => msg.id !== messageId);
    
    if (this.isOpen) {
      const messageElement = document.querySelector(`[data-message-id="${messageId}"]`);
      if (messageElement) {
        messageElement.style.animation = 'messageSlideOut 0.3s ease';
        setTimeout(() => {
          messageElement.remove();
          // Show empty state if no messages left
          if (this.messages.length === 0) {
            document.getElementById('empty-state').style.display = 'flex';
          }
        }, 300);
      }
    }
  }

  async deleteMessage(messageId) {
    if (confirm('Are you sure you want to delete this message?')) {
      try {
        const response = await fetch(`/messages/${messageId}`, {
          method: 'DELETE',
          credentials: 'include'
        });

        if (!response.ok) {
          const error = await response.json();
          alert(error.error || 'Failed to delete message');
        }
      } catch (error) {
        console.error('Error deleting message:', error);
        alert('Failed to delete message');
      }
    }
  }

  async sendMessage() {
    const input = document.getElementById('message-input');
    const message = input.value.trim();
    const sendButton = document.getElementById('send-message');

    if (!message) return;

    input.disabled = true;
    sendButton.disabled = true;

    try {
      const response = await fetch('/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({ message })
      });

      if (response.ok) {
        input.value = '';
        this.isTyping = false;
        this.sendTypingIndicator(false);
      } else {
        const error = await response.json();
        this.showError(error.error || 'Failed to send message');
      }
    } catch (error) {
      console.error('Error sending message:', error);
      this.showError('Failed to send message');
    } finally {
      input.disabled = false;
      sendButton.disabled = false;
      input.focus();
    }
  }

  showError(message) {
    const container = document.getElementById('messages-container');
    const errorDiv = document.createElement('div');
    errorDiv.className = 'message system';
    errorDiv.innerHTML = `
      <div class="message-content">❌ ${message}</div>
    `;
    container.appendChild(errorDiv);
    this.scrollToBottom();
    
    setTimeout(() => errorDiv.remove(), 3000);
  }

  incrementUnreadCount() {
    this.unreadCount++;
    const badge = document.getElementById('notification-badge');
    badge.textContent = this.unreadCount;
    badge.style.display = 'flex';
  }

  showNotification(message) {
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(`${message.username}: ${message.message.substring(0, 50)}${message.message.length > 50 ? '...' : ''}`, {
        icon: '/favicon.ico',
        badge: '/favicon.ico'
      });
    }
  }

  startNotificationCheck() {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission();
    }

    setInterval(() => {
      if (this.isOpen) {
        this.loadOnlineCount();
      }
    }, 30000);
  }

  scrollToBottom() {
    const container = document.getElementById('messages-container');
    container.scrollTop = container.scrollHeight;
  }
}

// Initialize messenger when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  window.messenger = new Messenger();
});

// Add disconnect handling
window.addEventListener('beforeunload', () => {
  if (window.messenger && window.messenger.eventSource) {
    window.messenger.eventSource.close();
  }
});

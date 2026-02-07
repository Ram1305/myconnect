const express = require('express');
const router = express.Router();
const Chat = require('../models/Chat');
const User = require('../models/User');
const { auth } = require('../middleware/auth');
const { sendChatNotification, sendNotificationToMultiple, saveNotificationToDb } = require('../services/notificationService');

// Get all chats for a user (excluding public chats - those are fetched separately)
router.get('/', auth, async (req, res) => {
  try {
    const chats = await Chat.find({
      participants: req.user._id,
      isPublic: { $ne: true } // Exclude public chats
    })
      .populate('participants', 'username mobileNumber profilePhoto')
      .populate('messages.sender', 'username profilePhoto')
      .sort({ lastMessageTime: -1 });

    res.json(chats);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get or create chat between two users
router.get('/with/:userId', auth, async (req, res) => {
  try {
    const otherUserId = req.params.userId;

    let chat = await Chat.findOne({
      participants: { $all: [req.user._id, otherUserId] },
      isPublic: { $ne: true } // Ensure we don't fetch the public group chat
    }).populate('participants', 'username mobileNumber profilePhoto');

    if (!chat) {
      chat = new Chat({
        participants: [req.user._id, otherUserId],
        messages: []
      });
      await chat.save();
      await chat.populate('participants', 'username mobileNumber profilePhoto');
    }

    res.json(chat);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Send message
router.post('/:chatId/message', auth, async (req, res) => {
  try {
    const { message } = req.body;
    const chat = await Chat.findById(req.params.chatId);

    if (!chat) {
      return res.status(404).json({ message: 'Chat not found' });
    }

    // For public chats, allow anyone to send messages
    // For private chats, check if user is a participant
    if (!chat.isPublic && !chat.participants.some(p => p.toString() === req.user._id.toString())) {
      return res.status(403).json({ message: 'Not authorized' });
    }

    // Add user to participants if it's a public chat and they're not already in
    if (chat.isPublic && !chat.participants.some(p => p.toString() === req.user._id.toString())) {
      chat.participants.push(req.user._id);
    }

    const newMessage = {
      sender: req.user._id,
      message: message,
      timestamp: new Date(),
      createdAt: new Date()
    };

    chat.messages.push(newMessage);
    chat.lastMessage = message;
    chat.lastMessageTime = new Date();

    await chat.save();
    await chat.populate('participants', 'username mobileNumber profilePhoto fcmToken');
    await chat.populate('messages.sender', 'username profilePhoto');

    // Emit real-time update via socket.io
    const io = req.app.get('io');
    if (io) {
      const populatedMessage = chat.messages[chat.messages.length - 1];
      io.to(req.params.chatId).emit('new_message', {
        chatId: req.params.chatId,
        message: populatedMessage
      });
      io.to(req.params.chatId).emit('chat_updated', {
        chatId: req.params.chatId,
        chat: chat
      });
    }

    // Send push notifications to other participants
    const senderId = req.user._id.toString();
    const otherParticipants = chat.participants.filter(
      p => p._id.toString() !== senderId && p.fcmToken
    );

    if (chat.isPublic) {
      // For group chat, send to all other participants
      const fcmTokens = otherParticipants.map(p => p.fcmToken).filter(Boolean);
      if (fcmTokens.length > 0) {
        const senderName = req.user.username || 'Someone';
        await sendNotificationToMultiple(
          fcmTokens,
          'My Connect Chat',
          `${senderName}: ${message}`,
          {
            type: 'chat',
            chatId: req.params.chatId,
            isGroupChat: 'true',
          }
        );
      }
    } else {
      // For private chat, send to the other participant
      if (otherParticipants.length > 0) {
        const recipient = otherParticipants[0];
        const senderName = req.user.username || 'Someone';
        if (recipient.fcmToken) {
          await sendChatNotification(
            recipient.fcmToken,
            senderName,
            message,
            req.params.chatId,
            false
          );

          // Save notification to DB for recipient
          await saveNotificationToDb(
            recipient._id,
            senderName,
            message,
            'chat',
            {
              chatId: req.params.chatId,
              isGroupChat: 'false'
            }
          );
        }
      }
    }

    res.json(chat);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get messages for a chat
router.get('/:chatId/messages', auth, async (req, res) => {
  try {
    const chat = await Chat.findById(req.params.chatId)
      .populate('participants', 'username mobileNumber profilePhoto')
      .populate('messages.sender', 'username profilePhoto');

    if (!chat) {
      return res.status(404).json({ message: 'Chat not found' });
    }

    // For public chats, allow anyone to view messages
    // For private chats, check if user is a participant
    if (!chat.isPublic && !chat.participants.some(p => p._id.toString() === req.user._id.toString())) {
      return res.status(403).json({ message: 'Not authorized' });
    }

    // Add user to participants if it's a public chat and they're not already in
    if (chat.isPublic && !chat.participants.some(p => p._id.toString() === req.user._id.toString())) {
      chat.participants.push(req.user._id);
      await chat.save();
      await chat.populate('participants', 'username mobileNumber profilePhoto');
    }

    res.json(chat);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get or create public My Connect chat (simpler route)
router.get('/public', auth, async (req, res) => {
  try {
    let chat = await Chat.findOne({
      isPublic: true,
      name: 'My Connect'
    }).populate('participants', 'username mobileNumber profilePhoto')
      .populate('messages.sender', 'username profilePhoto');

    if (!chat) {
      // Create the public chat
      chat = new Chat({
        participants: [req.user._id], // Add current user as first participant
        messages: [],
        isPublic: true,
        name: 'My Connect',
        lastMessage: '',
        lastMessageTime: new Date()
      });
      await chat.save();
      await chat.populate('participants', 'username mobileNumber profilePhoto');
    } else {
      // Add current user to participants if not already in
      const isParticipant = chat.participants.some(p => p._id.toString() === req.user._id.toString());
      if (!isParticipant) {
        chat.participants.push(req.user._id);
        await chat.save();
        await chat.populate('participants', 'username mobileNumber profilePhoto');
      }
    }

    res.json(chat);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get or create public My Connect chat (alternative route for backward compatibility)
router.get('/public/my-connect', auth, async (req, res) => {
  try {
    let chat = await Chat.findOne({
      isPublic: true,
      name: 'My Connect'
    }).populate('participants', 'username mobileNumber profilePhoto')
      .populate('messages.sender', 'username profilePhoto');

    if (!chat) {
      // Create the public chat
      chat = new Chat({
        participants: [req.user._id], // Add current user as first participant
        messages: [],
        isPublic: true,
        name: 'My Connect',
        lastMessage: '',
        lastMessageTime: new Date()
      });
      await chat.save();
      await chat.populate('participants', 'username mobileNumber profilePhoto');
    } else {
      // Add current user to participants if not already in
      const isParticipant = chat.participants.some(p => p._id.toString() === req.user._id.toString());
      if (!isParticipant) {
        chat.participants.push(req.user._id);
        await chat.save();
        await chat.populate('participants', 'username mobileNumber profilePhoto');
      }
    }

    res.json(chat);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;


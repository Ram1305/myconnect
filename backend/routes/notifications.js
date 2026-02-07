const express = require('express');
const router = express.Router();
const Notification = require('../models/Notification');
const { auth } = require('../middleware/auth');

// Get all notifications for current user
router.get('/', auth, async (req, res) => {
    try {
        const notifications = await Notification.find({ recipient: req.user._id })
            .sort({ createdAt: -1 })
            .limit(50); // Limit to last 50 notifications
        res.json(notifications);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Get unread count
router.get('/unread-count', auth, async (req, res) => {
    try {
        const count = await Notification.countDocuments({
            recipient: req.user._id,
            isRead: false
        });
        res.json({ count });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Mark single notification as read
router.put('/:id/read', auth, async (req, res) => {
    try {
        const notification = await Notification.findOneAndUpdate(
            { _id: req.params.id, recipient: req.user._id },
            { isRead: true },
            { new: true }
        );

        if (!notification) {
            return res.status(404).json({ message: 'Notification not found' });
        }

        res.json(notification);
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Mark all as read
router.put('/read-all', auth, async (req, res) => {
    try {
        await Notification.updateMany(
            { recipient: req.user._id, isRead: false },
            { isRead: true }
        );
        res.json({ message: 'All notifications marked as read' });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Delete a notification
router.delete('/:id', auth, async (req, res) => {
    try {
        const notification = await Notification.findOneAndDelete({
            _id: req.params.id,
            recipient: req.user._id
        });

        if (!notification) {
            return res.status(404).json({ message: 'Notification not found' });
        }

        res.json({ message: 'Notification deleted' });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Delete all notifications
router.delete('/', auth, async (req, res) => {
    try {
        await Notification.deleteMany({ recipient: req.user._id });
        res.json({ message: 'All notifications deleted' });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

// Test notification endpoint - sends a test push notification to current user
router.post('/test', auth, async (req, res) => {
    try {
        const User = require('../models/User');
        const { sendNotification, saveNotificationToDb } = require('../services/notificationService');
        
        const user = await User.findById(req.user._id);
        
        if (!user || !user.fcmToken) {
            return res.status(400).json({ 
                message: 'No FCM token found. Please ensure you are logged in and have granted notification permission.',
                sent: false
            });
        }

        const testTitle = 'Test Notification';
        const testBody = `This is a test notification sent at ${new Date().toLocaleString()}`;
        
        console.log(`🧪 [TEST] Sending test notification to user: ${user.username}`);
        console.log(`🧪 [TEST] FCM Token: ${user.fcmToken.substring(0, 20)}...`);
        
        // Send push notification
        const pushResult = await sendNotification(
            user.fcmToken,
            testTitle,
            testBody,
            {
                type: 'test',
                timestamp: new Date().toISOString(),
            }
        );

        // Save to database
        const dbResult = await saveNotificationToDb(
            user._id,
            testTitle,
            testBody,
            'test',
            {
                timestamp: new Date().toISOString(),
            }
        );

        if (pushResult) {
            console.log('✅ [TEST] Test notification sent successfully');
            res.json({ 
                message: 'Test notification sent successfully!',
                sent: true,
                saved: dbResult
            });
        } else {
            console.log('❌ [TEST] Failed to send push notification');
            res.status(500).json({ 
                message: 'Failed to send push notification. Check backend logs for details.',
                sent: false,
                saved: dbResult
            });
        }
    } catch (error) {
        console.error('❌ [TEST] Error sending test notification:', error);
        res.status(500).json({ 
            message: 'Server error', 
            error: error.message,
            sent: false
        });
    }
});

module.exports = router;

const express = require('express');
const router = express.Router();
const Event = require('../models/Event');
const User = require('../models/User');
const { auth, adminAuth } = require('../middleware/auth');
const { sendNotificationToMultiple } = require('../services/notificationService');

// Get all events (auth - filter by referralId for admin or optional query for super-admin)
router.get('/', auth, async (req, res) => {
  try {
    const { start, end, referralId: referralIdQuery } = req.query;
    
    const query = {};
    if (req.user.role === 'admin' && req.user.referralId) {
      query.referralId = req.user.referralId;
    } else if (referralIdQuery) {
      query.referralId = referralIdQuery;
    }
    if (start && end) {
      const dateFilter = {
        $or: [
          { start: { $gte: new Date(start), $lte: new Date(end) } },
          { end: { $gte: new Date(start), $lte: new Date(end) } },
          { start: { $lte: new Date(start) }, end: { $gte: new Date(end) } }
        ]
      };
      if (Object.keys(query).length > 0) {
        query.$and = [dateFilter];
      } else {
        Object.assign(query, dateFilter);
      }
    }
    
    const events = await Event.find(query)
      .populate('createdBy', 'username')
      .sort({ start: 1 });
    
    res.json(events);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get event by ID (public)
router.get('/:id', auth, async (req, res) => {
  try {
    const event = await Event.findById(req.params.id)
      .populate('createdBy', 'username');
    
    if (!event) {
      return res.status(404).json({ message: 'Event not found' });
    }
    
    res.json(event);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create event (admin only)
router.post('/', adminAuth, async (req, res) => {
  try {
    const { title, description, start, end, color, allDay } = req.body;
    
    if (!title || !start || !end) {
      return res.status(400).json({ message: 'Title, start, and end are required' });
    }
    
    const startDate = new Date(start);
    const endDate = new Date(end);
    
    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      return res.status(400).json({ message: 'Invalid date format' });
    }
    
    if (endDate < startDate) {
      return res.status(400).json({ message: 'End date must be after start date' });
    }
    
    const event = new Event({
      title: title.trim(),
      description: description ? description.trim() : null,
      start: startDate,
      end: endDate,
      color: color || '#6C63FF',
      allDay: allDay || false,
      createdBy: req.user._id,
      referralId: req.user.referralId || null
    });
    
    await event.save();
    
    const populatedEvent = await Event.findById(event._id)
      .populate('createdBy', 'username');
    
    // Send notification to all users
    try {
      const users = await User.find({ 
        fcmToken: { $exists: true, $ne: null, $ne: '' },
        status: 'approved' // Only send to approved users
      }).select('fcmToken');
      
      if (users.length > 0) {
        const fcmTokens = users.map(u => u.fcmToken).filter(Boolean);
        if (fcmTokens.length > 0) {
          await sendNotificationToMultiple(
            fcmTokens,
            'New Event Posted',
            `New event: ${title}`,
            {
              type: 'event',
              eventId: event._id.toString(),
            }
          );
          console.log(`✅ Event notification sent to ${fcmTokens.length} users`);
        }
      }
    } catch (notifError) {
      console.error('⚠️ Error sending event notifications:', notifError);
      // Don't fail the request if notification fails
    }
    
    res.status(201).json(populatedEvent);
  } catch (error) {
    console.error('Event creation error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update event (admin only)
router.put('/:id', adminAuth, async (req, res) => {
  try {
    const { title, description, start, end, color, allDay } = req.body;
    
    const event = await Event.findById(req.params.id);
    
    if (!event) {
      return res.status(404).json({ message: 'Event not found' });
    }
    
    if (title) event.title = title;
    if (description !== undefined) event.description = description;
    if (start) event.start = new Date(start);
    if (end) event.end = new Date(end);
    if (color) event.color = color;
    if (allDay !== undefined) event.allDay = allDay;
    
    if (event.end < event.start) {
      return res.status(400).json({ message: 'End date must be after start date' });
    }
    
    await event.save();
    
    const populatedEvent = await Event.findById(event._id)
      .populate('createdBy', 'username');
    
    res.json(populatedEvent);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete event (admin only)
router.delete('/:id', adminAuth, async (req, res) => {
  try {
    const event = await Event.findByIdAndDelete(req.params.id);
    
    if (!event) {
      return res.status(404).json({ message: 'Event not found' });
    }
    
    res.json({ message: 'Event deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;


const express = require('express');
const router = express.Router();
const MyList = require('../models/MyList');
const User = require('../models/User');
const { auth } = require('../middleware/auth');

// Get user's list
router.get('/', auth, async (req, res) => {
  try {
    const { latitude, longitude } = req.query;
    
    let myList = await MyList.findOne({ userId: req.user._id })
      .populate('members.memberId', 'username fatherName profilePhoto latitude longitude mobileNumber currentAddress');

    if (!myList) {
      myList = new MyList({ userId: req.user._id, members: [] });
      await myList.save();
    }

    // Calculate distance if user's location is provided
    if (latitude && longitude && myList.members && myList.members.length > 0) {
      const userLat = parseFloat(latitude);
      const userLon = parseFloat(longitude);
      
      // Convert to plain object and calculate distances
      const myListObj = myList.toObject();
      myListObj.members = myListObj.members.map(member => {
        const memberData = member.memberId;
        if (memberData && memberData.latitude != null && memberData.longitude != null) {
          const distance = calculateDistance(
            userLat,
            userLon,
            memberData.latitude,
            memberData.longitude
          );
          const distanceStr = distance.toFixed(2);
          return {
            ...member,
            memberId: {
              ...memberData,
              distance: distanceStr
            }
          };
        }
        return {
          ...member,
          memberId: {
            ...memberData,
            distance: null
          }
        };
      });
      
      return res.json(myListObj);
    }

    res.json(myList);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Add members to list
router.post('/add', auth, async (req, res) => {
  try {
    const { memberIds } = req.body; // Array of member IDs

    let myList = await MyList.findOne({ userId: req.user._id });

    if (!myList) {
      myList = new MyList({ userId: req.user._id, members: [] });
    }

    // Add new members (avoid duplicates)
    const existingMemberIds = myList.members.map(m => m.memberId.toString());
    const newMembers = memberIds
      .filter(id => !existingMemberIds.includes(id))
      .map(id => ({
        memberId: id,
        isActive: true
      }));

    myList.members.push(...newMembers);
    await myList.save();

    await myList.populate('members.memberId', 'username fatherName profilePhoto latitude longitude mobileNumber currentAddress');

    res.json(myList);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Toggle member active status
router.put('/toggle/:memberId', auth, async (req, res) => {
  try {
    const myList = await MyList.findOne({ userId: req.user._id });

    if (!myList) {
      return res.status(404).json({ message: 'List not found' });
    }

    const member = myList.members.find(
      m => m.memberId.toString() === req.params.memberId
    );

    if (!member) {
      return res.status(404).json({ message: 'Member not found in list' });
    }

    member.isActive = !member.isActive;
    await myList.save();

    await myList.populate('members.memberId', 'username fatherName profilePhoto latitude longitude mobileNumber currentAddress');

    res.json(myList);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Remove member from list
router.delete('/remove/:memberId', auth, async (req, res) => {
  try {
    const myList = await MyList.findOne({ userId: req.user._id });

    if (!myList) {
      return res.status(404).json({ message: 'List not found' });
    }

    myList.members = myList.members.filter(
      m => m.memberId.toString() !== req.params.memberId
    );

    await myList.save();

    res.json({ message: 'Member removed', myList });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Calculate distance between two coordinates (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the Earth in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distance in km
}

module.exports = router;


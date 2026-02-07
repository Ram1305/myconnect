const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { auth } = require('../middleware/auth');

// Get all approved users (for home page)
router.get('/approved', auth, async (req, res) => {
  try {
    const { search, latitude, longitude } = req.query;
    
    let query = { status: 'approved', _id: { $ne: req.user._id }, isAdmin: { $ne: true } };
    
    if (search) {
      // Escape special regex characters but keep case-insensitive search
      // This allows searching for "Jeyaram" with "jeyaram" or "JEYARAM"
      const escapedSearch = search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      
      query.$or = [
        { username: { $regex: escapedSearch, $options: 'i' } },
        { fatherName: { $regex: escapedSearch, $options: 'i' } },
        { mobileNumber: { $regex: escapedSearch, $options: 'i' } },
        // Location-based search
        { 'currentAddress.address': { $regex: escapedSearch, $options: 'i' } },
        { 'currentAddress.state': { $regex: escapedSearch, $options: 'i' } },
        { 'currentAddress.pincode': { $regex: escapedSearch, $options: 'i' } },
        // Also search in native address
        { 'nativeAddress.address': { $regex: escapedSearch, $options: 'i' } },
        { 'nativeAddress.state': { $regex: escapedSearch, $options: 'i' } },
        { 'nativeAddress.pincode': { $regex: escapedSearch, $options: 'i' } }
      ];
    }

    const users = await User.find(query).select('-password');
    
    // Calculate distance if lat/long provided
    let usersWithDistance = users;
    if (latitude && longitude) {
      usersWithDistance = users.map(user => {
        const distance = calculateDistance(
          parseFloat(latitude),
          parseFloat(longitude),
          user.latitude,
          user.longitude
        );
        return {
          ...user.toObject(),
          distance: distance.toFixed(2)
        };
      });
      
      // Sort by distance
      usersWithDistance.sort((a, b) => a.distance - b.distance);
    }

    res.json(usersWithDistance);
  } catch (error) {
    console.error('Get approved users error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get user by ID
router.get('/:id', auth, async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('-password');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json(user);
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


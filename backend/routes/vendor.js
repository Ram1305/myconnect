const express = require('express');
const router = express.Router();
const multer = require('multer');
const Banner = require('../models/Banner');
const { auth, adminAuth } = require('../middleware/auth');
const { bannerImageStorage } = require('../config/cloudinary');

// Configure multer for banner image uploads using Cloudinary
const upload = multer({ 
  storage: bannerImageStorage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB for banner images
  fileFilter: (req, file, cb) => {
    const allowedMimeTypes = /^image\/(jpeg|jpg|png|gif|webp)$/i;
    if (allowedMimeTypes.test(file.mimetype)) {
      return cb(null, true);
    } else {
      cb(new Error('Only image files are allowed!'));
    }
  }
});

// Get all banners (optional referralId query for filtering)
router.get('/getbanner', async (req, res) => {
  try {
    const { referralId: referralIdQuery } = req.query;
    const query = { isActive: true };
    if (referralIdQuery) query.referralId = referralIdQuery;
    const banners = await Banner.find(query)
      .populate('createdBy', 'username')
      .sort({ order: 1, createdAt: -1 });
    
    res.json({
      success: true,
      banners: banners
    });
  } catch (error) {
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
});

// Add banner (admin only)
router.post('/addbanner', adminAuth, upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ 
        success: false,
        message: 'Image is required' 
      });
    }
    
    // Get Cloudinary URL from uploaded file
    const imageUrl = req.file.path;
    
    if (!imageUrl || !imageUrl.startsWith('http')) {
      return res.status(400).json({ 
        success: false,
        message: 'Error uploading image' 
      });
    }
    
    // Get the highest order number
    const lastBanner = await Banner.findOne().sort({ order: -1 });
    const nextOrder = lastBanner ? (lastBanner.order + 1) : 0;
    
    const banner = new Banner({
      image: imageUrl,
      createdBy: req.user._id,
      isActive: true,
      order: nextOrder,
      referralId: req.user.referralId || null
    });
    
    await banner.save();
    
    const populatedBanner = await Banner.findById(banner._id)
      .populate('createdBy', 'username');
    
    res.status(201).json({
      success: true,
      message: 'Banner added successfully',
      banner: populatedBanner
    });
  } catch (error) {
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
});

// Delete banner (admin only)
router.delete('/deletebanner/:id', adminAuth, async (req, res) => {
  try {
    const banner = await Banner.findById(req.params.id);
    
    if (!banner) {
      return res.status(404).json({ 
        success: false,
        message: 'Banner not found' 
      });
    }
    
    // Optionally delete image from Cloudinary
    // You can extract the public_id from the image URL and delete it
    // For now, we'll just delete from database
    
    await Banner.findByIdAndDelete(req.params.id);
    
    res.json({ 
      success: true,
      message: 'Banner deleted successfully' 
    });
  } catch (error) {
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
});

// Update banner order (admin only)
router.put('/updatebannerorder/:id', adminAuth, async (req, res) => {
  try {
    const { order } = req.body;
    
    const banner = await Banner.findByIdAndUpdate(
      req.params.id,
      { order: order },
      { new: true }
    );
    
    if (!banner) {
      return res.status(404).json({ 
        success: false,
        message: 'Banner not found' 
      });
    }
    
    res.json({
      success: true,
      message: 'Banner order updated successfully',
      banner: banner
    });
  } catch (error) {
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
});

// Toggle banner active status (admin only)
router.put('/togglebanner/:id', adminAuth, async (req, res) => {
  try {
    const banner = await Banner.findById(req.params.id);
    
    if (!banner) {
      return res.status(404).json({ 
        success: false,
        message: 'Banner not found' 
      });
    }
    
    banner.isActive = !banner.isActive;
    await banner.save();
    
    res.json({
      success: true,
      message: `Banner ${banner.isActive ? 'activated' : 'deactivated'} successfully`,
      banner: banner
    });
  } catch (error) {
    res.status(500).json({ 
      success: false,
      message: 'Server error', 
      error: error.message 
    });
  }
});

module.exports = router;


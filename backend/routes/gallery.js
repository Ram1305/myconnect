const express = require('express');
const router = express.Router();
const multer = require('multer');
const { adminAuth } = require('../middleware/auth');
const Gallery = require('../models/Gallery');
const { galleryImageStorage } = require('../config/cloudinary');

// Multer setup for gallery images
const upload = multer({
  storage: galleryImageStorage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  fileFilter: (req, file, cb) => {
    const allowedMimeTypes = /^image\/(jpeg|jpg|png|gif|webp)$/i;
    if (allowedMimeTypes.test(file.mimetype)) {
      return cb(null, true);
    }
    cb(new Error('Only image files are allowed'));
  },
});

// GET /api/gallery - public list
router.get('/', async (req, res) => {
  try {
    const photos = await Gallery.find()
      .sort({ createdAt: -1 })
      .select('-__v')
      .populate('createdBy', 'username');

    res.json({ success: true, photos });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
});

// POST /api/gallery - admin only upload
router.post('/', adminAuth, upload.single('image'), async (req, res) => {
  try {
    if (!req.file || !req.file.path) {
      return res.status(400).json({
        success: false,
        message: 'Image is required',
      });
    }

    const photo = new Gallery({
      image: req.file.path,
      title: req.body.title || '',
      createdBy: req.user?._id,
    });

    await photo.save();
    const populated = await photo.populate('createdBy', 'username');

    res.status(201).json({
      success: true,
      message: 'Photo added',
      photo: populated,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
});

// Optional: DELETE /api/gallery/:id (admin)
router.delete('/:id', adminAuth, async (req, res) => {
  try {
    const photo = await Gallery.findById(req.params.id);
    if (!photo) {
      return res.status(404).json({ success: false, message: 'Photo not found' });
    }

    await photo.deleteOne();
    res.json({ success: true, message: 'Photo deleted' });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
});

module.exports = router;


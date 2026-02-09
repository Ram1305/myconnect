const express = require('express');
const router = express.Router();
const multer = require('multer');
const Blog = require('../models/Blog');
const User = require('../models/User');
const { auth, adminAuth } = require('../middleware/auth');
const { userProfileImageStorage } = require('../config/cloudinary');
const { sendNotificationToMultiple } = require('../services/notificationService');

// Configure multer for blog image uploads using Cloudinary
const upload = multer({ 
  storage: userProfileImageStorage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB for blog images
  fileFilter: (req, file, cb) => {
    const allowedMimeTypes = /^image\/(jpeg|jpg|png|gif|webp)$/i;
    if (allowedMimeTypes.test(file.mimetype)) {
      return cb(null, true);
    } else {
      cb(new Error('Only image files are allowed!'));
    }
  }
});

// Get all blogs (auth - filter by referralId for admin or optional query for super-admin)
router.get('/', auth, async (req, res) => {
  try {
    const { referralId: referralIdQuery } = req.query;
    const query = {};
    if (req.user.role === 'admin' && req.user.referralId) {
      query.referralId = req.user.referralId;
    } else if (referralIdQuery) {
      query.referralId = referralIdQuery;
    }
    const blogs = await Blog.find(query)
      .populate('createdBy', 'username profilePhoto')
      .populate('likes', 'username profilePhoto')
      .populate('comments.user', 'username profilePhoto')
      .sort({ createdAt: -1 });
    
    res.json(blogs);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Get blog by ID (public - increments view count)
router.get('/:id', auth, async (req, res) => {
  try {
    const blog = await Blog.findByIdAndUpdate(
      req.params.id,
      { $inc: { views: 1 } },
      { new: true }
    )
      .populate('createdBy', 'username profilePhoto')
      .populate('likes', 'username profilePhoto')
      .populate('comments.user', 'username profilePhoto');
    
    if (!blog) {
      return res.status(404).json({ message: 'Blog not found' });
    }
    
    res.json(blog);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Create blog (admin only)
router.post('/', adminAuth, upload.single('image'), async (req, res) => {
  try {
    const { title, description, location } = req.body;
    
    if (!title || !req.file) {
      return res.status(400).json({ message: 'Title and image are required' });
    }
    
    // Get Cloudinary URL from uploaded file
    const imageUrl = req.file.path;
    
    if (!imageUrl || !imageUrl.startsWith('http')) {
      return res.status(400).json({ message: 'Error uploading image' });
    }
    
    const blog = new Blog({
      title,
      description: description || null,
      image: imageUrl,
      location: location || null,
      createdBy: req.user._id,
      referralId: req.user.referralId || null
    });
    
    await blog.save();
    
    const populatedBlog = await Blog.findById(blog._id)
      .populate('createdBy', 'username profilePhoto')
      .populate('likes', 'username profilePhoto')
      .populate('comments.user', 'username profilePhoto');
    
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
            'New Blog Posted',
            `New blog: ${title}`,
            {
              type: 'blog',
              blogId: blog._id.toString(),
            }
          );
          console.log(`✅ Blog notification sent to ${fcmTokens.length} users`);
        }
      }
    } catch (notifError) {
      console.error('⚠️ Error sending blog notifications:', notifError);
      // Don't fail the request if notification fails
    }
    
    res.status(201).json(populatedBlog);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Update blog (admin only) - image is optional
router.put('/:id', adminAuth, upload.single('image'), async (req, res) => {
  try {
    const { title, description, location } = req.body;
    
    const blog = await Blog.findById(req.params.id);
    
    if (!blog) {
      return res.status(404).json({ message: 'Blog not found' });
    }
    
    if (title) blog.title = title.trim();
    if (description !== undefined) blog.description = description ? description.trim() : null;
    if (location !== undefined) blog.location = location ? location.trim() : null;
    
    // Update image if provided (optional for updates)
    if (req.file) {
      const imageUrl = req.file.path;
      if (imageUrl && imageUrl.startsWith('http')) {
        blog.image = imageUrl;
      } else {
        return res.status(400).json({ message: 'Error uploading image' });
      }
    }
    
    await blog.save();
    
    const populatedBlog = await Blog.findById(blog._id)
      .populate('createdBy', 'username profilePhoto')
      .populate('likes', 'username profilePhoto')
      .populate('comments.user', 'username profilePhoto');
    
    res.json(populatedBlog);
  } catch (error) {
    console.error('Blog update error:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete blog (admin only)
router.delete('/:id', adminAuth, async (req, res) => {
  try {
    const blog = await Blog.findByIdAndDelete(req.params.id);
    
    if (!blog) {
      return res.status(404).json({ message: 'Blog not found' });
    }
    
    res.json({ message: 'Blog deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Like/Unlike blog
router.post('/:id/like', auth, async (req, res) => {
  try {
    const blog = await Blog.findById(req.params.id);
    
    if (!blog) {
      return res.status(404).json({ message: 'Blog not found' });
    }
    
    const userId = req.user._id.toString();
    const isLiked = blog.likes.some(likeId => likeId.toString() === userId);
    
    if (isLiked) {
      blog.likes = blog.likes.filter(likeId => likeId.toString() !== userId);
    } else {
      blog.likes.push(req.user._id);
    }
    
    await blog.save();
    
    const populatedBlog = await Blog.findById(blog._id)
      .populate('createdBy', 'username profilePhoto')
      .populate('likes', 'username profilePhoto')
      .populate('comments.user', 'username profilePhoto');
    
    res.json(populatedBlog);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Add comment to blog
router.post('/:id/comment', auth, async (req, res) => {
  try {
    const { text } = req.body;
    
    if (!text || text.trim().isEmpty) {
      return res.status(400).json({ message: 'Comment text is required' });
    }
    
    const blog = await Blog.findById(req.params.id);
    
    if (!blog) {
      return res.status(404).json({ message: 'Blog not found' });
    }
    
    blog.comments.push({
      user: req.user._id,
      text: text.trim()
    });
    
    await blog.save();
    
    const populatedBlog = await Blog.findById(blog._id)
      .populate('createdBy', 'username profilePhoto')
      .populate('likes', 'username profilePhoto')
      .populate('comments.user', 'username profilePhoto');
    
    res.json(populatedBlog);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Delete comment (admin or comment owner)
router.delete('/:id/comment/:commentId', auth, async (req, res) => {
  try {
    const blog = await Blog.findById(req.params.id);
    
    if (!blog) {
      return res.status(404).json({ message: 'Blog not found' });
    }
    
    const comment = blog.comments.id(req.params.commentId);
    
    if (!comment) {
      return res.status(404).json({ message: 'Comment not found' });
    }
    
    // Check if user is admin or comment owner
    const isAdmin = req.user.isAdmin;
    const isOwner = comment.user.toString() === req.user._id.toString();
    
    if (!isAdmin && !isOwner) {
      return res.status(403).json({ message: 'Not authorized to delete this comment' });
    }
    
    blog.comments.pull(req.params.commentId);
    await blog.save();
    
    const populatedBlog = await Blog.findById(blog._id)
      .populate('createdBy', 'username profilePhoto')
      .populate('likes', 'username profilePhoto')
      .populate('comments.user', 'username profilePhoto');
    
    res.json(populatedBlog);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;


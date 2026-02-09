const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  text: {
    type: String,
    required: true,
    trim: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
}, { _id: true });

const blogSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    default: null,
    trim: true
  },
  image: {
    type: String,
    required: true
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  likes: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  comments: [commentSchema],
  views: {
    type: Number,
    default: 0
  },
  location: {
    type: String,
    default: null
  },
  referralId: {
    type: String,
    default: null,
    trim: true
  }
}, {
  timestamps: true
});

// Index for better query performance
blogSchema.index({ createdAt: -1 });
blogSchema.index({ createdBy: 1 });

module.exports = mongoose.model('Blog', blogSchema);


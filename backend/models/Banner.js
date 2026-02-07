const mongoose = require('mongoose');

const bannerSchema = new mongoose.Schema({
  image: {
    type: String,
    required: true
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  isActive: {
    type: Boolean,
    default: true
  },
  order: {
    type: Number,
    default: 0
  }
}, {
  timestamps: true
});

// Index for better query performance
bannerSchema.index({ createdAt: -1 });
bannerSchema.index({ isActive: 1 });
bannerSchema.index({ order: 1 });

module.exports = mongoose.model('Banner', bannerSchema);


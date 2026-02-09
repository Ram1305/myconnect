const mongoose = require('mongoose');

const GallerySchema = new mongoose.Schema(
  {
    image: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      trim: true,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    referralId: {
      type: String,
      default: null,
      trim: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Gallery', GallerySchema);


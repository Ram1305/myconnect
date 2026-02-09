const mongoose = require('mongoose');

const eventSchema = new mongoose.Schema({
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
  start: {
    type: Date,
    required: true
  },
  end: {
    type: Date,
    required: true
  },
  color: {
    type: String,
    default: '#6C63FF'
  },
  allDay: {
    type: Boolean,
    default: false
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  referralId: {
    type: String,
    default: null,
    trim: true
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Event', eventSchema);


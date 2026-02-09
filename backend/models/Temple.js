const mongoose = require('mongoose');

const templeSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
        trim: true
    },
    frontImage: {
        type: String,
        required: true
    },
    address: {
        type: String,
        required: true
    },
    images: [{
        type: String
    }],
    events: [{
        text: { type: String, required: true },
        image: { type: String, required: true },
        createdAt: { type: Date, default: Date.now }
    }],
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

module.exports = mongoose.model('Temple', templeSchema);

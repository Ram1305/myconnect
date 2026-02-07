const express = require('express');
const router = express.Router();
const multer = require('multer');
const { adminAuth } = require('../middleware/auth');
const Temple = require('../models/Temple');
const { galleryImageStorage } = require('../config/cloudinary');

const upload = multer({
    storage: galleryImageStorage,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

// GET /api/temples - List all temples
router.get('/', async (req, res) => {
    try {
        const temples = await Temple.find().sort({ createdAt: -1 });
        res.json({ success: true, temples });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
});

// GET /api/temples/:id - Get temple details
router.get('/:id', async (req, res) => {
    try {
        const temple = await Temple.findById(req.params.id);
        if (!temple) return res.status(404).json({ success: false, message: 'Temple not found' });
        res.json({ success: true, temple });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
});

// POST /api/temples - Add temple (Admin)
router.post('/', adminAuth, upload.single('image'), async (req, res) => {
    try {
        const { name, address } = req.body;
        if (!req.file) return res.status(400).json({ success: false, message: 'Front image is required' });

        const temple = new Temple({
            name,
            address,
            frontImage: req.file.path,
            createdBy: req.user._id
        });

        await temple.save();
        res.status(201).json({ success: true, message: 'Temple added', temple });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
});

// POST /api/temples/:id/images - Add gallery images (Admin)
router.post('/:id/images', adminAuth, upload.array('images', 10), async (req, res) => {
    try {
        const temple = await Temple.findById(req.params.id);
        if (!temple) return res.status(404).json({ success: false, message: 'Temple not found' });

        const imagePaths = req.files.map(file => file.path);
        temple.images.push(...imagePaths);
        await temple.save();

        res.json({ success: true, message: 'Images added', temple });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
});

// POST /api/temples/:id/events - Add event (Admin)
router.post('/:id/events', adminAuth, upload.single('image'), async (req, res) => {
    try {
        const { text } = req.body;
        const temple = await Temple.findById(req.params.id);
        if (!temple) return res.status(404).json({ success: false, message: 'Temple not found' });
        if (!req.file) return res.status(400).json({ success: false, message: 'Event image is required' });

        temple.events.push({
            text,
            image: req.file.path
        });

        await temple.save();
        res.json({ success: true, message: 'Event added', temple });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
});

// DELETE /api/temples/:id - Delete temple (Admin)
router.delete('/:id', adminAuth, async (req, res) => {
    try {
        console.log(`Attempting to delete temple: ${req.params.id} by admin: ${req.user._id}`);
        const temple = await Temple.findByIdAndDelete(req.params.id);
        if (!temple) return res.status(404).json({ success: false, message: 'Temple not found' });
        console.log(`Temple deleted successfully: ${req.params.id}`);
        res.json({ success: true, message: 'Temple deleted' });
    } catch (error) {
        console.error(`Error deleting temple ${req.params.id}:`, error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
});

// DELETE /api/temples/:id/images/:index - Delete gallery image (Admin)
router.delete('/:id/images/:index', adminAuth, async (req, res) => {
    try {
        console.log(`Attempting to delete image index ${req.params.index} from temple ${req.params.id}`);
        const temple = await Temple.findById(req.params.id);
        if (!temple) return res.status(404).json({ success: false, message: 'Temple not found' });

        const index = parseInt(req.params.index);
        if (isNaN(index) || index < 0 || index >= temple.images.length) {
            return res.status(400).json({ success: false, message: 'Invalid image index' });
        }

        const removedImage = temple.images.splice(index, 1);
        await temple.save();
        console.log(`Successfully removed image from temple ${req.params.id}`);

        res.json({ success: true, message: 'Image deleted', temple });
    } catch (error) {
        console.error(`Error deleting image from temple ${req.params.id}:`, error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
});

// DELETE /api/temples/:id/events/:eventId - Delete event (Admin)
router.delete('/:id/events/:eventId', adminAuth, async (req, res) => {
    try {
        console.log(`Attempting to delete event ${req.params.eventId} from temple ${req.params.id}`);
        const temple = await Temple.findById(req.params.id);
        if (!temple) return res.status(404).json({ success: false, message: 'Temple not found' });

        const initialLength = temple.events.length;
        temple.events = temple.events.filter(event => event._id.toString() !== req.params.eventId);

        if (temple.events.length === initialLength) {
            console.log(`Event ${req.params.eventId} not found in temple ${req.params.id}`);
            return res.status(404).json({ success: false, message: 'Event not found' });
        }

        await temple.save();
        console.log(`Successfully removed event ${req.params.eventId} from temple ${req.params.id}`);

        res.json({ success: true, message: 'Event deleted', temple });
    } catch (error) {
        console.error(`Error deleting event from temple ${req.params.id}:`, error);
        res.status(500).json({ success: false, message: 'Server error', error: error.message });
    }
});

module.exports = router;

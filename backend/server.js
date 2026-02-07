const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

// Initialize Firebase Admin
const { initializeFirebase } = require('./services/notificationService');
initializeFirebase();

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: [
      'http://localhost:1000',
      'http://127.0.0.1:1000',
      'http://10.0.2.2:1000',
      'http://192.168.29.61:1000',
      'http://192.168.29.61',
      'http://72.61.236.154:1000',
      /^http:\/\/192\.168\.\d+\.\d+/,
      /^http:\/\/10\.0\.2\.\d+/,
    ],
    credentials: true,
    methods: ['GET', 'POST'],
  },
});

// Middleware - CORS Configuration
const corsOptions = {
  origin: [
    'http://localhost:1000',
    'http://127.0.0.1:1000',
    'http://10.0.2.2:1000', // Android Emulator
    'http://192.168.29.61:1000', // Physical device on same network
    'http://192.168.29.61', // Without port
    'http://72.61.236.154:1000', // Production server
    /^http:\/\/192\.168\.\d+\.\d+/, // Allow any local network IP
    /^http:\/\/10\.0\.2\.\d+/, // Allow Android emulator variations
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
};

app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// Note: No local uploads directory needed - all images are stored in Cloudinary
// Only Cloudinary URLs are stored in the database

// Disable Mongoose buffering globally - fail fast instead of buffering
mongoose.set('bufferCommands', false);

// MongoDB Connection with improved error handling and reconnection
const mongoOptions = {
  serverSelectionTimeoutMS: 5000, // Timeout after 5s instead of 30s
  socketTimeoutMS: 45000, // Close sockets after 45s of inactivity
  connectTimeoutMS: 10000, // Give up initial connection after 10s
  maxPoolSize: 10, // Maintain up to 10 socket connections
  minPoolSize: 2, // Maintain at least 2 socket connections
};

// Set up connection event handlers (before connecting)
mongoose.connection.on('connected', () => {
  console.log('✅ Mongoose connected to MongoDB');
});

mongoose.connection.on('error', (err) => {
  console.error('❌ Mongoose connection error:', err);
});

mongoose.connection.on('disconnected', () => {
  console.warn('⚠️ Mongoose disconnected from MongoDB');
  // Attempt to reconnect after 5 seconds
  setTimeout(() => {
    console.log('Attempting to reconnect to MongoDB...');
    connectMongoDB().catch(err => console.error('Reconnection failed:', err));
  }, 5000);
});

// Handle process termination
process.on('SIGINT', async () => {
  await mongoose.connection.close();
  console.log('MongoDB connection closed due to app termination');
  process.exit(0);
});

// Connection function with retry logic
async function connectMongoDB() {
  try {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/myconnect';
    console.log('Attempting to connect to MongoDB...');

    // Check if already connected
    if (mongoose.connection.readyState === 1) {
      console.log('✅ MongoDB already connected');
      return;
    }

    await mongoose.connect(mongoUri, mongoOptions);
    console.log('✅ MongoDB Connected successfully');

  } catch (err) {
    console.error('❌ MongoDB Connection Error:', err.message);
    console.error('Full error:', err);

    // Retry connection after 5 seconds
    console.log('Retrying MongoDB connection in 5 seconds...');
    setTimeout(() => {
      connectMongoDB().catch(err => console.error('Retry failed:', err));
    }, 5000);
  }
}

// Start MongoDB connection
connectMongoDB();

// Define PORT before using it
const PORT = process.env.PORT || 1000;

// Helper: Express app.use() expects a middleware function (Router). Handles route modules
// that export: router directly, { router }, or { default: router } (ESM interop).
function useRoute(path, routeModule) {
  let middleware;
  if (typeof routeModule === 'function') {
    middleware = routeModule;
  } else if (routeModule && typeof routeModule.router === 'function') {
    middleware = routeModule.router;
  } else if (routeModule && typeof routeModule.default === 'function') {
    middleware = routeModule.default;
  }
  if (typeof middleware !== 'function') {
    const got = routeModule === null ? 'null' : (routeModule === undefined ? 'undefined' : typeof routeModule);
    throw new Error(`Route for ${path} must export an Express Router (function), got ${got}`);
  }
  app.use(path, middleware);
}

// Routes - each wrapped to log which route fails
const routes = [
  ['/api/auth', './routes/auth'],
  ['/api/users', './routes/users'],
  ['/api/admin', './routes/admin'],
  ['/api/chat', './routes/chat'],
  ['/api/mylist', './routes/mylist'],
  ['/api/notifications', './routes/notifications'],
  ['/api/events', './routes/events'],
  ['/api/blogs', './routes/blogs'],
  ['/api/vendor', './routes/vendor'],
  ['/api/whatsapp', './routes/whatsapp'],
  ['/api/gallery', './routes/gallery'],
  ['/api/temples', './routes/temples'],
];
routes.forEach(([path, modulePath]) => {
  try {
    useRoute(path, require(modulePath));
  } catch (err) {
    console.error(`Failed to load route ${path} (${modulePath}):`, err.message);
    throw err;
  }
});

// Health check endpoint
app.get('/api/health', async (req, res) => {
  try {
    const mongoStatus = mongoose.connection.readyState;
    const mongoStates = {
      0: 'disconnected',
      1: 'connected',
      2: 'connecting',
      3: 'disconnecting'
    };

    const healthStatus = {
      status: mongoStatus === 1 ? 'OK' : 'WARNING',
      message: 'My Connect API is running',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      database: {
        status: mongoStates[mongoStatus] || 'unknown',
        connected: mongoStatus === 1
      },
      server: {
        port: PORT,
        environment: process.env.NODE_ENV || 'development'
      }
    };

    const statusCode = mongoStatus === 1 ? 200 : 503;
    res.status(statusCode).json(healthStatus);
  } catch (error) {
    res.status(500).json({
      status: 'ERROR',
      message: 'Health check failed',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Socket.io connection handling
io.use((socket, next) => {
  // You can add authentication here if needed
  next();
});

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // Join a chat room
  socket.on('join_chat', (chatId) => {
    socket.join(chatId);
    console.log(`User ${socket.id} joined chat ${chatId}`);
  });

  // Leave a chat room
  socket.on('leave_chat', (chatId) => {
    socket.leave(chatId);
    console.log(`User ${socket.id} left chat ${chatId}`);
  });

  // Handle sending messages (for real-time updates)
  socket.on('send_message', async (data) => {
    // This will be handled by the API endpoint, but we can emit updates here
    socket.to(data.chatId).emit('new_message', {
      chatId: data.chatId,
      message: data.message
    });
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

// Make io available to routes
app.set('io', io);

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Socket.io server initialized`);
});


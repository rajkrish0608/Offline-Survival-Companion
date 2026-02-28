require('express-async-errors');
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');

const authRoutes = require('./routes/auth');
const contentRoutes = require('./routes/content');
const syncRoutes = require('./routes/sync');
const userRoutes = require('./routes/user');
const vaultRoutes = require('./routes/vault');
const adminRoutes = require('./routes/admin');

const { errorHandler } = require('./middleware/errorHandler');
const { authMiddleware } = require('./middleware/auth');

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files (admin dashboard etc.) BEFORE helmet so assets load
app.use(express.static(path.join(__dirname, '..', 'public')));

// Security middlewares — allow inline scripts/styles for admin dashboard
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'", "'unsafe-inline'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            fontSrc: ["'self'", "https://fonts.gstatic.com"],
            imgSrc: ["'self'", "data:"],
            connectSrc: ["'self'"],
        },
    },
}));
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
    credentials: true,
}));

// Rate limiting — general API
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    message: 'Too many requests from this IP',
});
app.use('/api/', limiter);

// Stricter rate limit for admin routes
const adminLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 30,
    message: 'Too many admin requests from this IP',
});
app.use('/api/admin/', adminLimiter);

// Body parsers
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Compression
app.use(compression());

// Logging
app.use(morgan('combined'));

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/content', contentRoutes);
app.use('/api/sync', authMiddleware, syncRoutes);
app.use('/api/user', authMiddleware, userRoutes);
app.use('/api/vault', authMiddleware, vaultRoutes);
app.use('/api/admin', adminRoutes);   // admin middleware is inside the router

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Not Found',
        message: `Route ${req.originalUrl} not found`,
    });
});

// Error handler
app.use(errorHandler);

// Start server
app.listen(PORT, () => {
    console.log(`
╭────────────────────────────────────────╮
│  Offline Survival Companion Backend    │
│  Running on port ${PORT}                  │
│  Database: PostgreSQL                  │
│  Vault:    Backblaze B2               │
╰────────────────────────────────────────╯
  `);
});

module.exports = app;

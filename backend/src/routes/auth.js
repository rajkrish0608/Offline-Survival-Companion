const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const Joi = require('joi');
const { dbRun, dbGet } = require('../config/database');
const { AppError } = require('../middleware/errorHandler');

const router = express.Router();

// Validation schemas
const registerSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().min(8).required(),
    name: Joi.string().required(),
    phone: Joi.string().required(),
});

const loginSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().required(),
});

// Generate JWT token
const generateToken = (userId, email) => {
    return jwt.sign(
        { userId, email },
        process.env.JWT_SECRET || 'your-secret-key',
        { expiresIn: '7d' }
    );
};

// Register
router.post('/register', async (req, res) => {
    // Validate request
    const { error, value } = registerSchema.validate(req.body);
    if (error) {
        return res.status(400).json({
            error: 'Validation Error',
            message: error.message,
        });
    }

    const { email, password, name, phone } = value;

    try {
        // Check if user already exists
        const existingUser = await dbGet('SELECT id FROM users WHERE email = ?', [email]);
        if (existingUser) {
            throw new AppError('User already exists', 409, 'Conflict');
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Create user
        const userId = `user_${Date.now()}`;
        await dbRun(
            `INSERT INTO users (id, email, name, phone, password_hash, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [userId, email, name, phone, hashedPassword, Date.now(), Date.now()]
        );

        // Generate token
        const token = generateToken(userId, email);

        res.status(201).json({
            message: 'User registered successfully',
            userId,
            token,
            user: { id: userId, email, name, phone },
        });
    } catch (err) {
        if (err instanceof AppError) {
            return res.status(err.statusCode).json({
                error: err.error,
                message: err.message,
            });
        }

        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Login
router.post('/login', async (req, res) => {
    // Validate request
    const { error, value } = loginSchema.validate(req.body);
    if (error) {
        return res.status(400).json({
            error: 'Validation Error',
            message: error.message,
        });
    }

    const { email, password } = value;

    try {
        // Get user
        const user = await dbGet('SELECT * FROM users WHERE email = ?', [email]);
        if (!user) {
            throw new AppError('Invalid credentials', 401, 'Unauthorized');
        }

        // Verify password
        const passwordMatch = await bcrypt.compare(password, user.password_hash);
        if (!passwordMatch) {
            throw new AppError('Invalid credentials', 401, 'Unauthorized');
        }

        // Generate token
        const token = generateToken(user.id, user.email);

        res.json({
            message: 'Logged in successfully',
            userId: user.id,
            token,
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                phone: user.phone,
            },
        });
    } catch (err) {
        if (err instanceof AppError) {
            return res.status(err.statusCode).json({
                error: err.error,
                message: err.message,
            });
        }

        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Refresh token
router.post('/refresh', async (req, res) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            throw new AppError('No token provided', 401, 'Unauthorized');
        }

        const token = authHeader.substring(7);
        const decoded = jwt.verify(
            token,
            process.env.JWT_SECRET || 'your-secret-key',
            { ignoreExpiration: true }
        );

        const newToken = generateToken(decoded.userId, decoded.email);

        res.json({
            message: 'Token refreshed',
            token: newToken,
        });
    } catch (err) {
        res.status(401).json({
            error: 'Unauthorized',
            message: 'Failed to refresh token',
        });
    }
});

module.exports = router;

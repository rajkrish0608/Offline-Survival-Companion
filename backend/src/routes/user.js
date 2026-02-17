const express = require('express');
const { dbGet, dbAll, dbRun } = require('../config/database');
const { AppError } = require('../middleware/errorHandler');

const router = express.Router();

// Get user profile
router.get('/profile', async (req, res) => {
    try {
        const userId = req.userId;

        const user = await dbGet(
            'SELECT id, email, name, phone, created_at, updated_at FROM users WHERE id = ?',
            [userId]
        );

        if (!user) {
            throw new AppError('User not found', 404, 'Not Found');
        }

        res.json({
            message: 'User profile retrieved',
            user,
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

// Update user profile
router.put('/profile', async (req, res) => {
    try {
        const userId = req.userId;
        const { name, phone } = req.body;

        if (!name && !phone) {
            return res.status(400).json({
                error: 'Validation Error',
                message: 'At least one field is required',
            });
        }

        const updates = [];
        const params = [];

        if (name) {
            updates.push('name = ?');
            params.push(name);
        }

        if (phone) {
            updates.push('phone = ?');
            params.push(phone);
        }

        updates.push('updated_at = ?');
        params.push(Date.now());
        params.push(userId);

        await dbRun(
            `UPDATE users SET ${updates.join(', ')} WHERE id = ?`,
            params
        );

        const user = await dbGet(
            'SELECT id, email, name, phone, created_at, updated_at FROM users WHERE id = ?',
            [userId]
        );

        res.json({
            message: 'User profile updated',
            user,
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Get emergency contacts
router.get('/emergency-contacts', async (req, res) => {
    try {
        const userId = req.userId;

        const contacts = await dbAll(
            `SELECT id, name, phone, relationship, is_primary, verified, created_at 
       FROM emergency_contacts 
       WHERE user_id = ? 
       ORDER BY is_primary DESC, created_at ASC`,
            [userId]
        );

        res.json({
            message: 'Emergency contacts retrieved',
            contacts,
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Add emergency contact
router.post('/emergency-contacts', async (req, res) => {
    try {
        const userId = req.userId;
        const { name, phone, relationship = 'Other' } = req.body;

        if (!name || !phone) {
            return res.status(400).json({
                error: 'Validation Error',
                message: 'Name and phone are required',
            });
        }

        const contactId = `contact_${Date.now()}`;

        await dbRun(
            `INSERT INTO emergency_contacts (id, user_id, name, phone, relationship, is_primary, verified, created_at)
       VALUES (?, ?, ?, ?, ?, 0, 0, ?)`,
            [contactId, userId, name, phone, relationship, Date.now()]
        );

        const contact = await dbGet(
            'SELECT * FROM emergency_contacts WHERE id = ?',
            [contactId]
        );

        res.status(201).json({
            message: 'Emergency contact added',
            contact,
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Update emergency contact
router.put('/emergency-contacts/:contactId', async (req, res) => {
    try {
        const userId = req.userId;
        const { contactId } = req.params;
        const { name, phone, relationship, is_primary } = req.body;

        // Verify contact belongs to user
        const contact = await dbGet(
            'SELECT id FROM emergency_contacts WHERE id = ? AND user_id = ?',
            [contactId, userId]
        );

        if (!contact) {
            return res.status(404).json({
                error: 'Not Found',
                message: 'Contact not found',
            });
        }

        const updates = [];
        const params = [];

        if (name !== undefined) {
            updates.push('name = ?');
            params.push(name);
        }

        if (phone !== undefined) {
            updates.push('phone = ?');
            params.push(phone);
        }

        if (relationship !== undefined) {
            updates.push('relationship = ?');
            params.push(relationship);
        }

        if (is_primary !== undefined) {
            updates.push('is_primary = ?');
            params.push(is_primary ? 1 : 0);
        }

        if (updates.length > 0) {
            params.push(contactId);
            await dbRun(
                `UPDATE emergency_contacts SET ${updates.join(', ')} WHERE id = ?`,
                params
            );
        }

        const updated = await dbGet(
            'SELECT * FROM emergency_contacts WHERE id = ?',
            [contactId]
        );

        res.json({
            message: 'Emergency contact updated',
            contact: updated,
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

// Delete emergency contact
router.delete('/emergency-contacts/:contactId', async (req, res) => {
    try {
        const userId = req.userId;
        const { contactId } = req.params;

        // Verify contact belongs to user
        const contact = await dbGet(
            'SELECT id FROM emergency_contacts WHERE id = ? AND user_id = ?',
            [contactId, userId]
        );

        if (!contact) {
            return res.status(404).json({
                error: 'Not Found',
                message: 'Contact not found',
            });
        }

        await dbRun(
            'DELETE FROM emergency_contacts WHERE id = ?',
            [contactId]
        );

        res.json({
            message: 'Emergency contact deleted',
        });
    } catch (err) {
        res.status(500).json({
            error: 'Internal Server Error',
            message: err.message,
        });
    }
});

module.exports = router;

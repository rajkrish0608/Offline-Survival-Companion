const jwt = require('jsonwebtoken');
const { AppError } = require('./errorHandler');

const authMiddleware = (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            throw new AppError('No token provided', 401, 'Unauthorized');
        }

        const token = authHeader.substring(7);
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');

        req.userId = decoded.userId;
        req.user = decoded;

        next();
    } catch (err) {
        if (err instanceof AppError) {
            return res.status(err.statusCode).json({
                error: err.error,
                message: err.message,
            });
        }

        res.status(401).json({
            error: 'Unauthorized',
            message: 'Invalid or expired token',
        });
    }
};

module.exports = {
    authMiddleware,
};

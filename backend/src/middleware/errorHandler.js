const errorHandler = (err, req, res, next) => {
    console.error('Error:', err);

    // Validation errors from Joi
    if (err.isJoi) {
        return res.status(400).json({
            error: 'Validation Error',
            message: err.message,
            details: err.details?.map(d => ({
                field: d.path.join('.'),
                message: d.message,
            })),
        });
    }

    // JWT errors
    if (err.name === 'JsonWebTokenError') {
        return res.status(401).json({
            error: 'Unauthorized',
            message: 'Invalid token',
        });
    }

    if (err.name === 'TokenExpiredError') {
        return res.status(401).json({
            error: 'Unauthorized',
            message: 'Token expired',
        });
    }

    // Custom application errors
    if (err.statusCode) {
        return res.status(err.statusCode).json({
            error: err.error || 'Error',
            message: err.message,
        });
    }

    // Generic error
    res.status(500).json({
        error: 'Internal Server Error',
        message: process.env.NODE_ENV === 'development' ? err.message : 'An error occurred',
    });
};

class AppError extends Error {
    constructor(message, statusCode = 500, error = 'Error') {
        super(message);
        this.statusCode = statusCode;
        this.error = error;
    }
}

module.exports = {
    errorHandler,
    AppError,
};

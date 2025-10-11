const express = require('express');
const router = express.Router();
// Import your database connection pool setup
const db = require('./db'); 

// POST /api/register endpoint
router.post('/register', async (req, res) => {
    // 1. Get data from the client (React Native app)
    const { name, email, password_hash } = req.body; 

    // Basic server-side validation
    if (!name || !email || !password_hash) {
        return res.status(400).json({ success: false, message: 'Missing required fields.' });
    }

    try {
        // 2. SQL Query to INSERT into the "User" table
        // NOTE: We use $1, $2, $3 to prevent SQL injection vulnerabilities.
        const query = `
            INSERT INTO "User" (name, email, password_hash)
            VALUES ($1, $2, $3)
            RETURNING user_id, email; 
        `;
        
        const result = await db.query(query, [name, email, password_hash]);
        
        // 3. Send success response with the new user's ID
        return res.status(201).json({
            success: true,
            message: 'User registered successfully.',
            user_id: result.rows[0].user_id
        });

    } catch (err) {
        console.error('Database Error:', err);

        // 4. Handle specific constraint violation (e.g., duplicate email)
        if (err.code === '23505') { // PostgreSQL code for unique_violation
            return res.status(409).json({ 
                success: false, 
                message: 'A user with this email already exists.' 
            });
        }

        // 5. Handle all other server errors
        return res.status(500).json({ 
            success: false, 
            message: 'Internal server error during registration.' 
        });
    }
});

module.exports = router;
// verify_connection.js

// 1. Import the connection module
const { query } = require('./db');

async function checkConnection() {
    console.log("Attempting to connect to PostgreSQL...");
    try {
        // 2. Execute a simple test query
        const result = await query('SELECT NOW() AS current_db_time');
        
        // 3. Log success and the data retrieved
        console.log("-----------------------------------------");
        console.log("✅ SUCCESS: Connection verified!");
        console.log("Database Time:", result.rows[0].current_db_time);
        console.log("-----------------------------------------");
        
    } catch (err) {
        // 4. Log failure and the error details
        console.error("❌ FAILURE: Could not connect to the database.");
        console.error("Error Details:", err.message);
        console.log("-----------------------------------------");
        
        // HINT: Check your database name, username, and password in db.js
    } finally {
        // 5. Ensure the process exits cleanly
        process.exit();
    }
}

checkConnection();
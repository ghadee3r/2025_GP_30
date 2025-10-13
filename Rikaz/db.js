// db.js (PostgreSQL Connection Pool Setup)
require('dotenv').config(); 

const { Pool } = require('pg');

const pool = new Pool({
    user: 'postgres',
    host: 'localhost',
    database: 'Rikaz', 
    password: process.env.PG_PASSWORD, 
     port: 5432,
});

module.exports = {
    query: (text, params) => pool.query(text, params),
};
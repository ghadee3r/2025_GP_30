// api_server.js (The main server entry point)
const express = require('express');
const bodyParser = require('body-parser');
// Assuming authRoutes.js is in the same directory
const authRoutes = require('./authRoutes'); 

const app = express();
const PORT = 8000; // The port your React Native app connects to (check your firewall!)

// --- MIDDLEWARE SETUP ---
// Allows the server to parse JSON bodies sent from the React Native app
app.use(bodyParser.json()); 
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.json()); 
app.use(require('cors')()); // Add CORS to allow connection from Expo Go development server

// --- ROUTE SETUP ---
// Attach the authentication routes handler. All endpoints in authRoutes.js 
// (like /register) will be accessible under the /api path.
app.use('/api', authRoutes); 

// Basic status check endpoint 
app.get('/', (req, res) => {
    res.send('Rikaz Backend API is running successfully.');
});

// Start the server
app.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
    console.log(`Access the API at http://localhost:${PORT}/api`);
});

// NOTE: To run this file, you use the command: node api_server.js
const express = require("express");
const bcrypt = require("bcryptjs");
const pool = require("./db");

const router = express.Router();

// REGISTER
router.post("/register", async (req, res) => {
  try {
    const { name, email, password } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ success: false, message: "Missing fields." });

    const userExists = await pool.query(`SELECT * FROM "User" WHERE email=$1`, [email]);
    if (userExists.rowCount > 0)
      return res.status(400).json({ success: false, message: "Email already registered." });

    const hashedPassword = await bcrypt.hash(password, 10);
    await pool.query(
      `INSERT INTO "User" (name, email, password_hash) VALUES ($1, $2, $3)`,
      [name, email, hashedPassword]
    );

    res.json({ success: true, message: "Account created successfully." });
  } catch (err) {
    console.error("Register Error:", err);
    res.status(500).json({ success: false, message: "Registration failed." });
  }
});

// LOGIN
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    const result = await pool.query(`SELECT * FROM "User" WHERE email=$1`, [email]);
    if (result.rowCount === 0)
      return res.status(400).json({ success: false, message: "Email not found." });

    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid)
      return res.status(401).json({ success: false, message: "Incorrect password." });

    res.json({ success: true, message: "Login successful." });
  } catch (err) {
    console.error("Login Error:", err);
    res.status(500).json({ success: false, message: "Login failed." });
  }
});

module.exports = router;
// NOTE: To use this file, you need to import and use it in your main server file (e.g., api_server.js) like so:
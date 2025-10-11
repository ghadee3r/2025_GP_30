~~~~~~~~~~~~Rikaz Project Quick Start Guideّّّّّّ~~~~~~~~~~~~~~
This guide provides the necessary steps for any teammate to set up the Backend API (Node.js) and Frontend App (Expo),
connect to their local PostgreSQL database, and start development.

--------------------------------------------------------------------------------
1. Prerequisites (Install Before Starting)
Ensure the following tools are installed on your system:
    PostgreSQL Server (Version 12+ recommended). Remember your master postgres user password.
    Node.js (LTS version).
    Git and a code editor (like VS Code).
    Expo Go App (on your phone/emulator).
--------------------------------------------------------------------------------
2. Project Setup & Dependencies
Clone the Repository: Clone the project from GitHub and navigate to the project root directory.
Install Dependencies: Run the following commands to install Node.js (Backend) and React Native (Frontend) dependencies:

# Install Node.js/Backend packages (Express, pg, dotenv, etc.)
npm install
# Install Frontend/Expo packages
npx expo install
--------------------------------------------------------------------------------
3. Database Initialization (Run ONLY ONCE)
You must create a local copy of the database structure.

1- Create Empty Database: Open your PostgreSQL client (psql or PGAdmin) and create a new, empty database instance named Rikaz:
CREATE DATABASE Rikaz;

2-Run the Blueprint: Execute the schema.sql file against the new database. This builds all the required tables (User, Preset, etc.):
# Run this command from your backend directory
psql -d Rikaz -f schema.sql -U postgres

--------------------------------------------------------------------------------
4. Configuration (Securing Credentials)
You must configure your machine's unique IP address and PostgreSQL password. These files are ignored by Git for security.
Create .env File(if it doesnt exist already): Create a new file named .env in the project root directory.

Add Configuration: Paste the following content into your new .env file and replace the placeholders with your local settings:

# --- SERVER CONFIGURATION ---
# 🚨 REQUIRED: Your computer's local IPv4 Address (e.g., 192.168.1.5).
# You must run 'ipconfig' or 'ifconfig' to find this address.
API_SERVER_IP=YOUR_LOCAL_IP_ADDRESS 
API_PORT=8000

# --- POSTGRESQL CREDENTIALS (Must be your local password) ---
# This must be the master password you set for PostgreSQL.
PG_PASSWORD=YOUR_DB_MASTER_PASSWORD

--------------------------------------------------------------------------------
5. Running the Project (Simultaneous Terminals)
You must use two separate terminal sessions to run the API and the mobile app at the same time.(click on your terminal and click on "split terminal")
Terminal 1: Backend API (The Server)	            | Terminal 2: Frontend App (The Client)
Action: Run the server to connect to PostgreSQL.    | Action: Start the Expo bundler.
Directory: Backend folder	                        | Directory: Project Root folder
Command: node api_server.js	                        | Command: npx expo start
Status: Should show Server listening on port 8000	| Status: Scan the QR code to load the app on your phone/emulator.
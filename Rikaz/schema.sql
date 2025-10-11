-- ===================================================================
-- RIKAZ PROJECT: FINAL POSTGRESQL DDL SCRIPT
-- This script creates all tables, custom types, and constraints.
-- ===================================================================

-- 1. DEFINE CUSTOM ENUM TYPES
-- These enforce valid values for specific columns
CREATE TYPE session_mode AS ENUM ('pomodoro', 'custom');
CREATE TYPE progress_report AS ENUM ('fully', 'partially', 'barely');
CREATE TYPE distraction_report AS ENUM ('low', 'medium', 'high');
CREATE TYPE sensitivity_level AS ENUM ('strict', 'medium', 'relaxed');


-- 2. CREATE User TABLE
CREATE TABLE IF NOT EXISTS "User" (
    user_id              SERIAL PRIMARY KEY,
    email                VARCHAR(255) UNIQUE NOT NULL,
    name                 VARCHAR(100) NOT NULL,
    profile_picture_url  VARCHAR(255) NULL,
    password_hash        VARCHAR(255) NOT NULL,
    
    -- Google Integration Fields
    google_account_id    VARCHAR(100) NULL,
    access_token         TEXT NULL,
    refresh_token        TEXT NULL,
    token_expiry         TIMESTAMPTZ NULL
);


-- 3. CREATE Sound_Option TABLE
CREATE TABLE IF NOT EXISTS "Sound_Option" (
    sound_id             SERIAL PRIMARY KEY,
    sound_name           VARCHAR(100) UNIQUE NOT NULL,
    sound_file_path      VARCHAR(255) NOT NULL
);


-- 4. CREATE Preset TABLE
CREATE TABLE IF NOT EXISTS "Preset" (
    preset_id                   SERIAL PRIMARY KEY,
    user_id                     INT NOT NULL,
    preset_name                 VARCHAR(100) NOT NULL,

    -- Notification toggles
    notification_light          BOOLEAN NOT NULL DEFAULT FALSE, 
    notification_sound          BOOLEAN NOT NULL DEFAULT FALSE, 
    
    detection_sensitivity_level sensitivity_level NOT NULL,

    -- Trigger Flags
    trigger_phone_use           BOOLEAN NOT NULL DEFAULT FALSE,
    trigger_absence             BOOLEAN NOT NULL DEFAULT FALSE,
    trigger_talking             BOOLEAN NOT NULL DEFAULT FALSE,
    trigger_sleeping            BOOLEAN NOT NULL DEFAULT FALSE,

    -- Constraints
    CONSTRAINT uc_user_preset_name UNIQUE (user_id, preset_name),
    CONSTRAINT chk_at_least_one_notification CHECK (
        notification_light OR notification_sound
    ),
    CONSTRAINT chk_at_least_one_trigger CHECK (
        trigger_phone_use OR trigger_absence OR trigger_talking OR trigger_sleeping
    ),

    CONSTRAINT fk_user_preset FOREIGN KEY (user_id) 
        REFERENCES "User"(user_id) ON DELETE CASCADE
);


-- 5. CREATE Focus_Session TABLE
CREATE TABLE IF NOT EXISTS "Focus_Session" (
    session_id             SERIAL PRIMARY KEY,
    user_id                INT NOT NULL,
    preset_id              INT NULL, 
    sound_id               INT NULL, 

    session_type           session_mode NOT NULL,
    start_time             TIMESTAMPTZ NOT NULL,
    end_time               TIMESTAMPTZ NOT NULL,
    
    total_duration         INT NOT NULL CHECK (total_duration >= 0),
    
    progress_level         progress_report NULL,
    distraction_level      distraction_report NULL,
    
    distraction_count      INT NOT NULL DEFAULT 0,
    camera_monitored       BOOLEAN NOT NULL DEFAULT FALSE,
    received_reinforcement TEXT NULL,

    -- FOREIGN KEYS
    CONSTRAINT fk_user_session FOREIGN KEY (user_id) 
        REFERENCES "User"(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_preset_session FOREIGN KEY (preset_id) 
        REFERENCES "Preset"(preset_id) ON DELETE SET NULL,
    CONSTRAINT fk_sound_session FOREIGN KEY (sound_id) 
        REFERENCES "Sound_Option"(sound_id) ON DELETE SET NULL
);
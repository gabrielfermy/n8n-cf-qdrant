#!/bin/bash
set -e

echo "--- [START] Running custom initialization script (init-dbs-chat.sh) ---"
echo "Configuring 'chat_memory' database (STM schema with WA mapping) ..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-'EOSQL'
-- Table: channels
-- Stores information about each WhatsApp bot/number
CREATE TABLE IF NOT EXISTS channels (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    phone_number VARCHAR(255) UNIQUE NOT NULL
);

-- Table: contacts
-- Collects and maps user numbers and names
CREATE TABLE IF NOT EXISTS contacts (
    id BIGSERIAL PRIMARY KEY,
    wa_id VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255)
);

-- Table: groups
-- Stores information about WhatsApp groups
CREATE TABLE IF NOT EXISTS groups (
    id BIGSERIAL PRIMARY KEY,
    group_id VARCHAR(255) UNIQUE NOT NULL,
    group_name VARCHAR(255)
);

-- Table: group_members (The join table)
-- Tracks which users belong to which groups
CREATE TABLE IF NOT EXISTS group_members (
    id BIGSERIAL PRIMARY KEY,
    contact_id BIGINT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
    group_id BIGINT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    first_interaction_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (contact_id, group_id)
);

-- Table: sessions
-- Tracks conversations for a specific bot, contact, or group
CREATE TABLE IF NOT EXISTS sessions (
    id BIGSERIAL PRIMARY KEY,
    contact_id BIGINT REFERENCES contacts(id),
    group_id BIGINT REFERENCES groups(id),
    session_key VARCHAR(255) UNIQUE NOT NULL,
    channel_id BIGINT REFERENCES channels(id),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table: messages
-- Stores messages with all relevant metadata
CREATE TABLE IF NOT EXISTS messages (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    message_id VARCHAR(255) UNIQUE,
    sender_id BIGINT REFERENCES contacts(id),
    from_me BOOLEAN,
    role VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    wa_timestamp TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for optimized queries
CREATE INDEX IF NOT EXISTS idx_sessions_contact_channel ON sessions(contact_id, channel_id);
CREATE INDEX IF NOT EXISTS idx_sessions_group_channel ON sessions(group_id, channel_id);
CREATE INDEX IF NOT EXISTS idx_messages_session_time ON messages(session_id, wa_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender_time ON messages(sender_id, wa_timestamp DESC);
EOSQL

echo "--- [SUCCESS] 'chat_memory' database configured with extended schema. ---"
echo "--- [COMPLETE] PostgreSQL initialization finished. ---"

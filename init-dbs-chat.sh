#!/bin/bash
set -e

echo "--- [START] Running custom initialization script (init-dbs-chat.sh) ---"
echo "Configuring 'chat_memory' database (STM schema with WA mapping) ..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-'EOSQL'
-- =====================================================
-- Table: sessions
-- Tracks conversations per user or group
-- =====================================================
CREATE TABLE IF NOT EXISTS sessions (
    id BIGSERIAL PRIMARY KEY,
    me_id VARCHAR(255) NOT NULL,        -- our own WA number (e.g. 6282241935282@c.us)
    user_id VARCHAR(255) NOT NULL,      -- resolved contactId (for private) or groupId (for group)
    channel_id VARCHAR(255) NOT NULL,      -- waha822 or waha813
    is_group BOOLEAN NOT NULL DEFAULT FALSE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- Table: messages
-- Stores messages per session with WA metadata
-- =====================================================
CREATE TABLE IF NOT EXISTS messages (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    message_id VARCHAR(255) UNIQUE,     -- WA messageId for deduplication
    actor_id VARCHAR(255),              -- who sent it (meId, contactId, or group member)
    from_me BOOLEAN,                    -- true if sent by me, false otherwise
    role VARCHAR(50) NOT NULL,          -- 'user', 'assistant', 'system'
    content TEXT NOT NULL,              -- body text of the message
    wa_timestamp TIMESTAMPTZ,           -- WA-provided timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- Indexes for faster retrieval
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_sessions_chat
    ON sessions(chat_id);

CREATE INDEX IF NOT EXISTS idx_messages_session_time
    ON messages(session_id, wa_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_messages_actor_time
    ON messages(actor_id, wa_timestamp DESC);

EOSQL

echo "--- [SUCCESS] 'chat_memory' database configured with extended schema. ---"
echo "--- [COMPLETE] PostgreSQL initialization finished. ---"

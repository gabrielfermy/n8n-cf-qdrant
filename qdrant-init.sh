#!/bin/sh
set -e

echo "--- [START] Running custom Qdrant initialization (qdrant-init.sh) ---"

# Qdrant host (change if needed)
QDRANT_HOST="${QDRANT_HOST:-http://qdrant:6333}"

# Collections to create (POSIX array replacement)
COLLECTIONS="longterm_memory user_knowledge"

# Wait for Qdrant to be available
MAX_RETRIES=20
SLEEP_INTERVAL=3

echo "Waiting for Qdrant at $QDRANT_HOST..."
i=1
while [ $i -le $MAX_RETRIES ]; do
    if curl -s "$QDRANT_HOST/collections" >/dev/null 2>&1; then
        echo "Qdrant is ready."
        break
    else
        echo "  -> Attempt $i/$MAX_RETRIES: Qdrant not ready, waiting $SLEEP_INTERVAL sec..."
        sleep $SLEEP_INTERVAL
    fi
    i=$((i + 1))
done

if [ $i -gt $MAX_RETRIES ]; then
    echo "Qdrant did not start in time. Exiting."
    exit 1
fi

# Function to create a collection if it doesn't exist
create_collection() {
    name=$1
    echo "Checking collection: $name..."

    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$QDRANT_HOST/collections/$name")
    if [ "$status_code" -eq 200 ]; then
        echo "  -> Collection '$name' exists, skipping."
    else
        echo "  -> Creating collection '$name'..."
        response=$(curl -s -X PUT "$QDRANT_HOST/collections/$name" \
            -H "Content-Type: application/json" \
            -d '{
                "vectors": {
                    "size": 768,
                    "distance": "Cosine"
                }
            }')
        echo "  -> Response: $response"
    fi
}

# Loop through collections (POSIX compliant)
for c in $COLLECTIONS; do
    create_collection "$c"
done

echo "--- [DONE] Qdrant initialization complete ---"

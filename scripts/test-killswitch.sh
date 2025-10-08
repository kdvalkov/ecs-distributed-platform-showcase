#!/bin/bash

# Killswitch Feature Test Script
# Tests the self-destruct endpoint functionality

set -e

echo "🧪 Killswitch Feature Test"
echo "=========================="
echo ""

# Configuration
APP_URL="${APP_URL:-http://localhost:3000}"
BASIC_AUTH="${BASIC_AUTH:-admin:changeme}"

echo "Testing against: $APP_URL"
echo ""

# Test 1: Health check (should work)
echo "Test 1: Health Check (before killswitch)"
echo "----------------------------------------"
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/health")
if [ "$HEALTH_STATUS" = "200" ]; then
    echo "✅ Health check passed (status: $HEALTH_STATUS)"
else
    echo "❌ Health check failed (status: $HEALTH_STATUS)"
    exit 1
fi
echo ""

# Test 2: Get initial instance info
echo "Test 2: Get Initial Instance Info"
echo "----------------------------------"
INITIAL_HOSTNAME=$(curl -s -u "$BASIC_AUTH" "$APP_URL/api/info" | jq -r '.instance.hostname')
echo "Current hostname: $INITIAL_HOSTNAME"
echo ""

# Test 3: Killswitch without confirmation (should fail)
echo "Test 3: Killswitch Without Confirmation (should fail)"
echo "-----------------------------------------------------"
RESPONSE=$(curl -s -u "$BASIC_AUTH" -X POST "$APP_URL/api/killswitch" \
    -H "Content-Type: application/json" \
    -d '{"confirm": false}')
SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
if [ "$SUCCESS" = "false" ]; then
    echo "✅ Correctly rejected request without confirmation"
    echo "Response: $(echo $RESPONSE | jq -r '.message')"
else
    echo "❌ Should have rejected request without confirmation"
    exit 1
fi
echo ""

# Test 4: Killswitch with confirmation (should work)
echo "Test 4: Killswitch With Confirmation"
echo "------------------------------------"
echo "⚠️  WARNING: This will terminate the application!"
echo "Press ENTER to continue or Ctrl+C to cancel..."
read

RESPONSE=$(curl -s -u "$BASIC_AUTH" -X POST "$APP_URL/api/killswitch" \
    -H "Content-Type: application/json" \
    -d '{"confirm": true}')
SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
    echo "✅ Killswitch activated successfully"
    echo ""
    echo "Response details:"
    echo "$RESPONSE" | jq '.'
    echo ""
    echo "Hostname: $(echo $RESPONSE | jq -r '.hostname')"
    echo "Task ARN: $(echo $RESPONSE | jq -r '.taskArn')"
    echo "Termination Time: $(echo $RESPONSE | jq -r '.terminationTime')"
else
    echo "❌ Killswitch activation failed"
    echo "Response: $RESPONSE"
    exit 1
fi

echo ""
echo "Waiting 10 seconds for container to terminate..."
sleep 10

# Test 5: Verify container has restarted (if in ECS)
echo ""
echo "Test 5: Check if New Container Started"
echo "--------------------------------------"
echo "Waiting 30 seconds for new container to start..."
sleep 30

echo "Attempting to connect to new container..."
for i in {1..5}; do
    echo "Attempt $i/5..."
    NEW_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/health" 2>/dev/null || echo "000")
    if [ "$NEW_HEALTH" = "200" ]; then
        echo "✅ New container is healthy!"
        
        NEW_HOSTNAME=$(curl -s -u "$BASIC_AUTH" "$APP_URL/api/info" | jq -r '.instance.hostname')
        echo "New hostname: $NEW_HOSTNAME"
        
        if [ "$NEW_HOSTNAME" != "$INITIAL_HOSTNAME" ]; then
            echo "✅ Hostname changed - failover successful!"
        else
            echo "⚠️  Hostname unchanged - may be running locally"
        fi
        
        break
    fi
    
    if [ $i -eq 5 ]; then
        echo "⚠️  Container not responding after 5 attempts"
        echo "This is expected if running locally without auto-restart"
    fi
    
    sleep 5
done

echo ""
echo "🎉 Test completed!"
echo ""
echo "Summary:"
echo "--------"
echo "Initial hostname: $INITIAL_HOSTNAME"
echo "Final hostname:   $NEW_HOSTNAME"
if [ "$NEW_HOSTNAME" != "$INITIAL_HOSTNAME" ]; then
    echo "Status: ✅ FAILOVER SUCCESSFUL"
else
    echo "Status: ⚠️  NO FAILOVER (expected for local development)"
fi

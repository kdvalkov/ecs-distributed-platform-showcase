# Self-Destruct Killswitch Feature

## Overview

The application now includes a **self-destruct killswitch** feature that allows you to demonstrate infrastructure resilience and automatic failover with a single button click. This is perfect for live demonstrations and showcasing your infrastructure's recovery capabilities.

## Visual Flow

```
┌──────────────────────────────────────────────────────────────┐
│  User clicks "SELF-DESTRUCT" button                          │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  POST /api/killswitch with {"confirm": true}                 │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Server responds immediately (success message)                │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  5-second countdown displayed in UI                           │
│  Database connections closed gracefully                       │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Container terminates (process.exit(0))                       │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  ECS detects task stopped                                     │
│  Service count: 2 → 1 (below desired count)                   │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  ECS Scheduler launches new task                              │
│  Task state: PENDING → RUNNING → HEALTHY                      │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  ALB health checks pass                                       │
│  New task registered in target group                          │
└───────────────────────────┬──────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Traffic flows to new container                               │
│  User refreshes page → sees new hostname                      │
│  ✅ FAILOVER COMPLETE (10-30 seconds)                         │
└──────────────────────────────────────────────────────────────┘
```

## What It Does

When activated, the killswitch:
1. **Gracefully terminates** the current container/task
2. **Closes database connections** cleanly
3. **Triggers ECS failover** - ECS detects the stopped task
4. **Automatically launches** a new replacement task
5. **Maintains availability** - ALB routes traffic to healthy tasks

**Total Recovery Time**: ~10-30 seconds

## How to Use

### Method 1: Web UI (Recommended for Demos)

1. Open your application in a browser
2. Scroll to the bottom of the page
3. Find the **"💣 Infrastructure Demo: Self-Destruct"** section
4. Click the red **"🔴 ACTIVATE SELF-DESTRUCT"** button
5. Confirm the action in the dialog
6. Watch the 5-second countdown
7. The container will terminate
8. Refresh the page after 10-30 seconds to see the new container

### Method 2: API Endpoint

```bash
# Using curl
curl -X POST https://your-app-url/api/killswitch \
  -u admin:changeme \
  -H "Content-Type: application/json" \
  -d '{"confirm": true}'
```

```bash
# Using httpie
http POST https://your-app-url/api/killswitch \
  -a admin:changeme \
  confirm:=true
```

```javascript
// Using JavaScript/fetch
fetch('/api/killswitch', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ confirm: true })
})
.then(response => response.json())
.then(data => console.log(data));
```

## API Response

```json
{
  "success": true,
  "message": "Self-destruct sequence activated",
  "hostname": "ip-10-0-1-123.eu-central-1.compute.internal",
  "taskArn": "arn:aws:ecs:eu-central-1:123456789012:task/devops-showcase-dev-cluster/abc123...",
  "terminationTime": "2025-10-08T12:34:56.789Z",
  "info": "This container will terminate in 5 seconds. ECS will automatically start a new task."
}
```

## Security

- Protected by **Basic Authentication** (same as the rest of the app)
- Requires explicit confirmation: `{"confirm": true}`
- Graceful shutdown - gives application time to close connections
- Logs all killswitch activations with timestamps

## What Gets Logged

When the killswitch is activated, you'll see:

```
🔴 KILLSWITCH ACTIVATED! Self-destruct sequence initiated...
📦 Terminating container: ip-10-0-1-123.eu-central-1.compute.internal
🏷️  ECS Task ARN: arn:aws:ecs:eu-central-1:123456789012:task/...
🔌 Closing database connections...
💥 Self-destruct completed! Container terminating now...
```

## Monitoring the Failover

### Option 1: Watch ECS Service Events
```bash
watch -n 2 'aws ecs describe-services \
  --cluster devops-showcase-dev-cluster \
  --services devops-showcase-dev-service \
  --query "services[0].events[0:5]" \
  --output table'
```

### Option 2: Monitor Tasks
```bash
watch -n 2 'aws ecs list-tasks \
  --cluster devops-showcase-dev-cluster \
  --service-name devops-showcase-dev-service \
  --query "taskArns" \
  --output table'
```

### Option 3: Watch Application
Keep refreshing the application page and observe the hostname changes.

## Use Cases

### 1. Live Demonstrations
Perfect for showing non-technical stakeholders how resilient infrastructure works without complex CLI commands.

### 2. Training
Excellent for teaching teams about:
- Container orchestration
- Health checks and monitoring
- Auto-scaling and recovery
- Zero-downtime deployments

### 3. Testing
Quick way to verify:
- ECS service auto-recovery
- ALB health checks
- Database connection pooling
- Graceful shutdown procedures

### 4. Load Testing
Combine with load testing tools to demonstrate:
- Zero dropped requests during failover
- Seamless traffic redistribution
- Service resilience under load

## Demo Script Example

Here's a suggested script for demonstrating the feature:

> "Let me show you how our infrastructure handles failures automatically. I'm going to deliberately crash this container by clicking this self-destruct button."
>
> *Click button, show countdown*
>
> "Watch the hostname at the top - it shows which container we're connected to. In about 30 seconds, you'll see it change to a different container."
>
> *Wait, refresh page*
>
> "See? We're now on a completely different container. The old one was terminated, and AWS ECS automatically launched this replacement. The load balancer detected the failure and redirected traffic. This happened with zero downtime - any other users would have been seamlessly redirected to healthy containers."

## Technical Details

### What Happens Behind the Scenes

1. **Client Clicks Button** → JavaScript sends POST to `/api/killswitch`
2. **Server Receives Request** → Validates authentication and confirmation
3. **Response Sent** → Server immediately responds with success message
4. **Database Cleanup** → Connection pool is gracefully closed
5. **5-Second Delay** → Allows time for response to reach client
6. **Process Exit** → `process.exit(0)` terminates Node.js
7. **Container Stops** → Docker container exits
8. **ECS Detects Failure** → Service sees task count below desired
9. **New Task Launched** → ECS scheduler starts replacement
10. **Health Checks Pass** → New task becomes healthy
11. **ALB Registration** → New task added to load balancer
12. **Traffic Resumes** → Requests flow to new container

### Why 5 Seconds?

The 5-second delay serves several purposes:
- Ensures HTTP response reaches the client
- Gives the UI time to display the countdown
- Allows database connections to close gracefully
- Makes the process visible and understandable
- Creates suspense for demonstrations 😄

## Troubleshooting

### Button doesn't work
- Check browser console for JavaScript errors
- Verify basic auth credentials are correct
- Ensure you clicked "OK" on the confirmation dialog

### Container doesn't restart
- Check ECS service desired count
- Verify ECS service auto-scaling is enabled
- Check CloudWatch logs for errors
- Ensure IAM permissions are correct

### Takes longer than 30 seconds
- Normal during high load periods
- May take longer if pulling new container image
- Check ECS instance health
- Review ECS events for details

## Code Implementation

The feature is implemented in `app/server.js`:

- **Frontend**: HTML button with JavaScript countdown
- **Backend**: POST endpoint at `/api/killswitch`
- **Authentication**: Protected by existing basic auth middleware
- **Graceful Shutdown**: Closes DB connections before exit

See the full implementation in the source code for details.

## See Also

- [FAILOVER_DEMO.md](./FAILOVER_DEMO.md) - Complete failover testing guide
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Infrastructure architecture details
- [app/README.md](../app/README.md) - Application documentation

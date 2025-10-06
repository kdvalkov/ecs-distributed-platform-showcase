# DevOps Showcase Application

A Node.js Express application designed to demonstrate AWS infrastructure capabilities including load balancing, database connectivity, and container orchestration.

## Features

- 🎨 Beautiful web dashboard with real-time infrastructure information
- 📊 Request counter stored in PostgreSQL database
- 🏥 Health check endpoints for load balancer integration
- 🐳 Container metadata display (hostname, IP, resources)
- 🌍 AWS environment information (region, AZ, ECS task details)
- 💾 Database connectivity verification
- ⏱️ Uptime tracking

## Application Endpoints

### Main Endpoints

- `GET /` - Main dashboard (HTML)
  - Displays comprehensive infrastructure information
  - Shows real-time container and database status
  - Increments request counter in database

- `GET /api/info` - JSON API endpoint
  - Returns all infrastructure data in JSON format
  - Useful for monitoring and automation

### Health Check Endpoints

- `GET /health` - Deep health check
  - Verifies database connectivity
  - Returns 200 if healthy, 503 if unhealthy
  - Used by ALB for routing decisions

- `GET /ready` - Readiness probe
  - Simple check that application is running
  - Always returns 200 if server is responding

## Environment Variables

Required:
- `DB_HOST` - PostgreSQL host address
- `DB_PORT` - Database port (default: 5432)
- `DB_NAME` - Database name
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password

Optional:
- `PORT` - Application port (default: 3000)
- `NODE_ENV` - Environment (production/development)
- `AWS_REGION` - AWS region for metadata
- `AWS_AVAILABILITY_ZONE` - Current availability zone

## Local Development

### Prerequisites

- Node.js >= 22.0.0
- PostgreSQL database (local or remote)

### Setup

1. Install dependencies:
```bash
npm install
```

2. Copy environment file:
```bash
cp .env.example .env
```

3. Update `.env` with your database credentials

4. Run locally:
```bash
npm start
```

For development with auto-reload:
```bash
npm run dev
```

### Local Testing with Docker

```bash
# Build image
docker build -t devops-showcase-app .

# Run with environment variables
docker run -d \
  -p 3000:3000 \
  -e DB_HOST=your-db-host \
  -e DB_PORT=5432 \
  -e DB_NAME=devops_showcase \
  -e DB_USER=dbadmin \
  -e DB_PASSWORD=your-password \
  devops-showcase-app

# Test health endpoint
curl http://localhost:3000/health
```

## Database Schema

The application automatically creates the following table on startup:

```sql
CREATE TABLE IF NOT EXISTS request_counter (
  id SERIAL PRIMARY KEY,
  count BIGINT DEFAULT 0,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Architecture Integration

This application is designed to work seamlessly with:

- **ECS (Elastic Container Service)**: Runs as containerized tasks
- **ALB (Application Load Balancer)**: Health checks and traffic distribution
- **RDS (Relational Database Service)**: PostgreSQL backend
- **CloudWatch**: Logging and monitoring

## Container Configuration

### Resource Requirements

- **CPU**: 256 units (0.25 vCPU)
- **Memory**: 512 MB
- **Port**: 3000

### Health Check Configuration

Docker health check runs every 30 seconds:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', ...)"
```

## Monitoring

### Application Logs

Logs are written to stdout/stderr and captured by CloudWatch:

```
✅ Database initialized successfully
🚀 DevOps Showcase Application Started
📍 Server running on: http://0.0.0.0:3000
🏥 Health check: http://0.0.0.0:3000/health
```

### Metrics to Monitor

- Request count (from database)
- Container uptime
- Database connection status
- Response times
- Error rates

## Performance Considerations

### Connection Pooling

The application uses `pg.Pool` for efficient database connections:
- Max connections: 20
- Idle timeout: 30 seconds
- Connection timeout: 2 seconds

### Graceful Shutdown

The application handles SIGTERM and SIGINT signals:
```javascript
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  await pool.end();
  process.exit(0);
});
```

## Security Features

- ✅ Non-root user in Docker container
- ✅ Multi-stage build for smaller image size
- ✅ No sensitive data in logs
- ✅ Parameterized database queries (SQL injection prevention)
- ✅ Connection timeouts configured

## Troubleshooting

### Database Connection Issues

Check environment variables:
```bash
docker exec <container-id> env | grep DB_
```

Test database connectivity:
```bash
docker exec <container-id> node -e "
const { Pool } = require('pg');
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD
});
pool.query('SELECT NOW()', (err, res) => {
  console.log(err ? err : res.rows);
  pool.end();
});
"
```

### Container Won't Start

Check logs:
```bash
docker logs <container-id>
```

Common issues:
1. Database not accessible (check security groups)
2. Wrong database credentials
3. Port already in use

## Dependencies

Production:
- `express` - Web framework
- `pg` - PostgreSQL client
- `dotenv` - Environment variable management

Development:
- `nodemon` - Auto-reload during development

## License

MIT License - see root README.md

## Related Documentation

- [Architecture Documentation](../docs/ARCHITECTURE.md)
- [Deployment Guide](../docs/DEPLOYMENT.md)
- [Fail-Over Testing](../docs/FAILOVER_DEMO.md)
- [Main README](../README.md)

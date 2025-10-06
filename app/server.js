const express = require('express');
const { Pool } = require('pg');
const os = require('os');
const fs = require('fs');
const basicAuth = require('express-basic-auth');

const app = express();
const PORT = process.env.PORT || 3000;

// Application start time for uptime calculation
const startTime = Date.now();

// Basic authentication middleware
const BASIC_AUTH_USER = process.env.BASIC_AUTH_USER || 'admin';
const BASIC_AUTH_PASSWORD = process.env.BASIC_AUTH_PASSWORD || 'changeme';

// Middleware to apply basic auth selectively (skip health endpoints)
const conditionalBasicAuth = (req, res, next) => {
  // Skip authentication for health check endpoints
  if (req.path === '/health' || req.path === '/ready') {
    return next();
  }
  
  // Apply basic auth for all other endpoints
  if (BASIC_AUTH_USER && BASIC_AUTH_PASSWORD) {
    return basicAuth({
      users: { [BASIC_AUTH_USER]: BASIC_AUTH_PASSWORD },
      challenge: true,
      realm: 'DevOps Showcase',
    })(req, res, next);
  }
  
  next();
};

if (BASIC_AUTH_USER && BASIC_AUTH_PASSWORD) {
  app.use(conditionalBasicAuth);
  console.log('🔒 Basic authentication enabled (health endpoints excluded)');
}

// PostgreSQL connection pool
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'devops_showcase',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Initialize database table
async function initDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS request_counter (
        id SERIAL PRIMARY KEY,
        count BIGINT DEFAULT 0,
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    const result = await pool.query('SELECT COUNT(*) FROM request_counter');
    if (parseInt(result.rows[0].count) === 0) {
      await pool.query('INSERT INTO request_counter (count) VALUES (0)');
    }
    
    console.log('✅ Database initialized successfully');
  } catch (error) {
    console.error('❌ Database initialization error:', error.message);
  }
}

// Get container/instance metadata
function getInstanceInfo() {
  const hostname = os.hostname();
  const platform = os.platform();
  const arch = os.arch();
  const cpus = os.cpus().length;
  const totalMemory = (os.totalmem() / (1024 ** 3)).toFixed(2);
  const freeMemory = (os.freemem() / (1024 ** 3)).toFixed(2);
  
  // Try to get ECS metadata
  let ecsMetadata = null;
  try {
    const metadataUri = process.env.ECS_CONTAINER_METADATA_URI_V4;
    if (metadataUri) {
      ecsMetadata = {
        taskArn: process.env.ECS_TASK_ARN || 'Not available',
        containerName: process.env.ECS_CONTAINER_NAME || 'Not available',
      };
    }
  } catch (error) {
    // ECS metadata not available (local dev)
  }
  
  return {
    hostname,
    platform,
    arch,
    cpus,
    totalMemory: `${totalMemory} GB`,
    freeMemory: `${freeMemory} GB`,
    nodeVersion: process.version,
    region: process.env.AWS_REGION || 'Not set',
    availabilityZone: process.env.AWS_AVAILABILITY_ZONE || 'Not set',
    ecsMetadata,
  };
}

// Get uptime in human-readable format
function getUptime() {
  const uptimeMs = Date.now() - startTime;
  const seconds = Math.floor(uptimeMs / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  if (days > 0) return `${days}d ${hours % 24}h ${minutes % 60}m`;
  if (hours > 0) return `${hours}h ${minutes % 60}m ${seconds % 60}s`;
  if (minutes > 0) return `${minutes}m ${seconds % 60}s`;
  return `${seconds}s`;
}

// Check database connectivity
async function checkDatabase() {
  try {
    const result = await pool.query('SELECT NOW() as time, version() as version');
    return {
      status: 'connected',
      timestamp: result.rows[0].time,
      version: result.rows[0].version.split(' ').slice(0, 2).join(' '),
    };
  } catch (error) {
    return {
      status: 'disconnected',
      error: error.message,
    };
  }
}

// Increment request counter in database
async function incrementCounter() {
  try {
    const result = await pool.query(`
      UPDATE request_counter 
      SET count = count + 1, last_updated = CURRENT_TIMESTAMP 
      RETURNING count
    `);
    return result.rows[0].count;
  } catch (error) {
    console.error('Error incrementing counter:', error.message);
    return null;
  }
}

// Health check endpoint (for ALB)
app.get('/health', async (req, res) => {
  try {
    const dbStatus = await checkDatabase();
    if (dbStatus.status === 'connected') {
      res.status(200).json({ status: 'healthy', database: 'connected' });
    } else {
      res.status(503).json({ status: 'unhealthy', database: 'disconnected' });
    }
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', error: error.message });
  }
});

// Ready check endpoint
app.get('/ready', (req, res) => {
  res.status(200).json({ status: 'ready' });
});

// Main dashboard endpoint
app.get('/', async (req, res) => {
  const instanceInfo = getInstanceInfo();
  const dbStatus = await checkDatabase();
  const requestCount = await incrementCounter();
  const uptime = getUptime();
  
  // Generate HTML response
  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Showcase - Infrastructure Demo</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            text-align: center;
            color: white;
            margin-bottom: 30px;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .card {
            background: white;
            border-radius: 10px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        .card h2 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.5em;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #eee;
        }
        .info-row:last-child {
            border-bottom: none;
        }
        .label {
            font-weight: 600;
            color: #555;
        }
        .value {
            color: #333;
            font-family: 'Courier New', monospace;
        }
        .status-badge {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.85em;
        }
        .status-connected {
            background: #10b981;
            color: white;
        }
        .status-disconnected {
            background: #ef4444;
            color: white;
        }
        .counter {
            text-align: center;
            font-size: 3em;
            color: #667eea;
            font-weight: bold;
            margin: 20px 0;
        }
        .timestamp {
            text-align: center;
            color: #999;
            font-size: 0.9em;
            margin-top: 20px;
        }
        .highlight {
            background: #f0f9ff;
            padding: 15px;
            border-radius: 5px;
            margin: 10px 0;
            border-left: 4px solid #667eea;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 DevOps Infrastructure Showcase</h1>
            <p>AWS ECS + RDS + ALB Demonstration</p>
        </div>
        
        <div class="grid">
            <div class="card">
                <h2>📦 Container Information</h2>
                <div class="info-row">
                    <span class="label">Hostname:</span>
                    <span class="value">${instanceInfo.hostname}</span>
                </div>
                <div class="info-row">
                    <span class="label">Platform:</span>
                    <span class="value">${instanceInfo.platform} (${instanceInfo.arch})</span>
                </div>
                <div class="info-row">
                    <span class="label">Node Version:</span>
                    <span class="value">${instanceInfo.nodeVersion}</span>
                </div>
                <div class="info-row">
                    <span class="label">CPUs:</span>
                    <span class="value">${instanceInfo.cpus}</span>
                </div>
                <div class="info-row">
                    <span class="label">Memory:</span>
                    <span class="value">${instanceInfo.freeMemory} free / ${instanceInfo.totalMemory}</span>
                </div>
                <div class="info-row">
                    <span class="label">Uptime:</span>
                    <span class="value">${uptime}</span>
                </div>
            </div>
            
            <div class="card">
                <h2>🌍 AWS Information</h2>
                <div class="info-row">
                    <span class="label">Region:</span>
                    <span class="value">${instanceInfo.region}</span>
                </div>
                <div class="info-row">
                    <span class="label">Availability Zone:</span>
                    <span class="value">${instanceInfo.availabilityZone}</span>
                </div>
                ${instanceInfo.ecsMetadata ? `
                <div class="highlight">
                    <div class="info-row">
                        <span class="label">ECS Task ARN:</span>
                    </div>
                    <div style="word-break: break-all; font-size: 0.85em; margin-top: 5px;">
                        ${instanceInfo.ecsMetadata.taskArn}
                    </div>
                    <div class="info-row" style="margin-top: 10px;">
                        <span class="label">Container Name:</span>
                        <span class="value">${instanceInfo.ecsMetadata.containerName}</span>
                    </div>
                </div>
                ` : '<p style="color: #999; text-align: center; margin-top: 20px;">Running in local development mode</p>'}
            </div>
            
            <div class="card">
                <h2>💾 Database Status</h2>
                <div class="info-row">
                    <span class="label">Status:</span>
                    <span class="status-badge status-${dbStatus.status}">${dbStatus.status}</span>
                </div>
                ${dbStatus.status === 'connected' ? `
                <div class="info-row">
                    <span class="label">Version:</span>
                    <span class="value">${dbStatus.version}</span>
                </div>
                <div class="info-row">
                    <span class="label">Timestamp:</span>
                    <span class="value">${new Date(dbStatus.timestamp).toISOString()}</span>
                </div>
                ` : `
                <div style="color: #ef4444; margin-top: 15px; padding: 10px; background: #fee; border-radius: 5px;">
                    <strong>Error:</strong> ${dbStatus.error}
                </div>
                `}
            </div>
            
            <div class="card">
                <h2>📊 Request Counter</h2>
                <p style="text-align: center; color: #666; margin-bottom: 10px;">
                    Total requests served (stored in RDS):
                </p>
                <div class="counter">
                    ${requestCount !== null ? requestCount.toLocaleString() : 'N/A'}
                </div>
                <p style="text-align: center; color: #999; font-size: 0.9em;">
                    Each page refresh increments this counter in the database
                </p>
            </div>
        </div>
        
        <div class="card">
            <h2>🔧 Infrastructure Components</h2>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-top: 15px;">
                <div style="text-align: center; padding: 15px; background: #f0f9ff; border-radius: 5px;">
                    <div style="font-size: 2em; margin-bottom: 5px;">⚖️</div>
                    <div style="font-weight: 600;">Application Load Balancer</div>
                    <div style="font-size: 0.85em; color: #666;">Distributing traffic</div>
                </div>
                <div style="text-align: center; padding: 15px; background: #f0f9ff; border-radius: 5px;">
                    <div style="font-size: 2em; margin-bottom: 5px;">🐳</div>
                    <div style="font-weight: 600;">ECS on EC2</div>
                    <div style="font-size: 0.85em; color: #666;">Container orchestration</div>
                </div>
                <div style="text-align: center; padding: 15px; background: #f0f9ff; border-radius: 5px;">
                    <div style="font-size: 2em; margin-bottom: 5px;">🗄️</div>
                    <div style="font-weight: 600;">RDS PostgreSQL</div>
                    <div style="font-size: 0.85em; color: #666;">Multi-AZ database</div>
                </div>
                <div style="text-align: center; padding: 15px; background: #f0f9ff; border-radius: 5px;">
                    <div style="font-size: 2em; margin-bottom: 5px;">🔄</div>
                    <div style="font-weight: 600;">Auto-Scaling</div>
                    <div style="font-size: 0.85em; color: #666;">Automatic fail-over</div>
                </div>
            </div>
        </div>
        
        <div class="timestamp">
            Generated at: ${new Date().toISOString()} | Refresh to test load balancing
        </div>
    </div>
</body>
</html>
  `;
  
  res.send(html);
});

// API endpoint for JSON response
app.get('/api/info', async (req, res) => {
  const instanceInfo = getInstanceInfo();
  const dbStatus = await checkDatabase();
  const requestCount = await incrementCounter();
  const uptime = getUptime();
  
  res.json({
    instance: instanceInfo,
    database: dbStatus,
    requestCount,
    uptime,
    timestamp: new Date().toISOString(),
  });
});

// Start server
async function startServer() {
  await initDatabase();
  
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`
╔════════════════════════════════════════════════════════════╗
║  🚀 DevOps Showcase Application Started                   ║
╚════════════════════════════════════════════════════════════╝

📍 Server running on: http://0.0.0.0:${PORT}
🏥 Health check:      http://0.0.0.0:${PORT}/health
📊 API endpoint:      http://0.0.0.0:${PORT}/api/info

Container: ${os.hostname()}
Node: ${process.version}
Environment: ${process.env.NODE_ENV || 'development'}
    `);
  });
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');
  await pool.end();
  process.exit(0);
});

startServer();

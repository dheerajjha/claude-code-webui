const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');
const path = require('path');
const fs = require('fs');

// Ensure logs directory exists
const logsDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Custom format for relay logs
const relayFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.json(),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    return JSON.stringify({
      timestamp,
      level,
      message,
      ...meta
    });
  })
);

// Daily rotate file transport for relay logs
const relayFileTransport = new DailyRotateFile({
  filename: path.join(logsDir, 'relay-%DATE%.log'),
  datePattern: 'YYYY-MM-DD',
  zippedArchive: true,
  maxSize: '20m',
  maxFiles: '14d', // Keep logs for 14 days
  format: relayFormat
});

// Daily rotate file transport for error logs
const errorFileTransport = new DailyRotateFile({
  filename: path.join(logsDir, 'error-%DATE%.log'),
  datePattern: 'YYYY-MM-DD',
  zippedArchive: true,
  maxSize: '20m',
  maxFiles: '30d', // Keep error logs for 30 days
  level: 'error',
  format: relayFormat
});

// Create logger instance
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: relayFormat,
  transports: [
    relayFileTransport,
    errorFileTransport
  ]
});

// Add console transport in development
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

// Custom logging methods for relay operations
logger.relayRequest = (req, targetUrl) => {
  logger.info('Relay Request', {
    type: 'relay_request',
    method: req.method,
    originalUrl: req.originalUrl,
    targetUrl: targetUrl,
    userAgent: req.get('User-Agent'),
    ip: req.ip,
    headers: {
      contentType: req.get('Content-Type'),
      authorization: req.get('Authorization') ? '[PRESENT]' : '[NONE]'
    },
    body: req.method === 'POST' ? (req.body || '[STREAM]') : undefined,
    timestamp: new Date().toISOString()
  });
};

logger.relayResponse = (req, response, duration, error = null) => {
  const logData = {
    type: 'relay_response',
    method: req.method,
    originalUrl: req.originalUrl,
    statusCode: response?.status || (error ? 500 : 200),
    duration: `${duration}ms`,
    ip: req.ip,
    timestamp: new Date().toISOString()
  };

  if (error) {
    logData.error = {
      message: error.message,
      code: error.code,
      stack: error.stack
    };
    logger.error('Relay Response Error', logData);
  } else {
    logger.info('Relay Response Success', logData);
  }
};

logger.relayStream = (req, chunkCount, totalBytes) => {
  logger.info('Relay Stream Complete', {
    type: 'relay_stream',
    method: req.method,
    originalUrl: req.originalUrl,
    chunkCount: chunkCount,
    totalBytes: totalBytes,
    ip: req.ip,
    timestamp: new Date().toISOString()
  });
};

logger.websocketConnection = (connectionId, event, data = {}) => {
  logger.info('WebSocket Event', {
    type: 'websocket',
    connectionId: connectionId,
    event: event,
    ...data,
    timestamp: new Date().toISOString()
  });
};

module.exports = logger;
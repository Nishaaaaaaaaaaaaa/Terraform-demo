/**
 * Structured application logger.
 *
 * Every record goes two places:
 *   1. stdout as JSON  - so `docker logs` stays useful and the container-log
 *                        pipeline picks it up.
 *   2. the OTel logs SDK - via @opentelemetry/instrumentation-winston, which
 *                        patches winston and stamps each record with the
 *                        active trace_id / span_id. That is what makes
 *                        "jump from this slow trace to its logs" work.
 */
"use strict";

const winston = require("winston");

const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || "info",
    // Timestamp + error stacks + JSON body: greppable and machine parseable.
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: {
        service: process.env.OTEL_SERVICE_NAME || "crud-server-express",
    },
    transports: [new winston.transports.Console()],
});

module.exports = logger;

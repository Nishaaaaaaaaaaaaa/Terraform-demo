/**
 * HTTP access logging.
 *
 * Emits one structured record per request in the spirit of the combined log
 * format, but as JSON so each field is independently queryable in SigNoz
 * (e.g. `http.status_code >= 500`, `http.route = '/user/:id'`).
 *
 * Records are written through the shared winston logger, so they inherit the
 * trace context and land next to the application logs.
 */
"use strict";

const morgan = require("morgan");
const logger = require("../logger");

// Express exposes the matched route pattern; falling back to the raw path
// keeps unmatched (404) requests visible without exploding cardinality.
morgan.token("route", (req) => (req.route && req.route.path) || req.baseUrl || "unmatched");

const FORMAT = JSON.stringify({
    remote_addr: ":remote-addr",
    method: ":method",
    url: ":url",
    route: ":route",
    status: ":status",
    duration_ms: ":response-time",
    bytes: ":res[content-length]",
    referrer: ":referrer",
    user_agent: ":user-agent",
    http_version: ":http-version",
});

const accessLog = morgan(FORMAT, {
    skip: (req) => req.path === "/healthz",
    stream: {
        write: (line) => {
            let parsed;
            try {
                parsed = JSON.parse(line);
            } catch {
                logger.info(line.trim(), { log_type: "access" });
                return;
            }

            const status = Number(parsed.status) || 0;
            const level = status >= 500 ? "error" : status >= 400 ? "warn" : "info";

            logger.log(level, `${parsed.method} ${parsed.url} ${parsed.status}`, {
                log_type: "access",
                "http.method": parsed.method,
                "http.route": parsed.route,
                "http.target": parsed.url,
                "http.status_code": status,
                "http.response_time_ms": Number(parsed.duration_ms) || 0,
                "http.response_size_bytes": Number(parsed.bytes) || 0,
                "http.user_agent": parsed.user_agent,
                "http.flavor": parsed.http_version,
                "client.address": parsed.remote_addr,
            });
        },
    },
});

module.exports = accessLog;

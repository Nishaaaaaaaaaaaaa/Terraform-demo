/**
 * OpenTelemetry bootstrap.
 *
 * Loaded via `node --require ./src/telemetry.js src/app.js` so that every
 * library is patched before the application requires it.
 *
 * Emits three signals to the SigNoz OTLP endpoint:
 *   traces  - express / http / prisma spans. SigNoz derives the R.E.D metrics
 *             (request rate, error rate, latency) from these via its
 *             signozspanmetrics connector, which powers the APM views.
 *   metrics - Node.js runtime metrics (event loop, heap, GC, handles).
 *   logs    - winston records, automatically stamped with trace_id / span_id.
 *
 * Configuration is entirely environment driven (see compose.yaml):
 *   OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_SERVICE_NAME, OTEL_RESOURCE_ATTRIBUTES
 */
"use strict";

const { NodeSDK } = require("@opentelemetry/sdk-node");
const { getNodeAutoInstrumentations } = require("@opentelemetry/auto-instrumentations-node");
const { OTLPTraceExporter } = require("@opentelemetry/exporter-trace-otlp-proto");
const { OTLPMetricExporter } = require("@opentelemetry/exporter-metrics-otlp-proto");
const { OTLPLogExporter } = require("@opentelemetry/exporter-logs-otlp-proto");
const { PeriodicExportingMetricReader } = require("@opentelemetry/sdk-metrics");
const { BatchLogRecordProcessor } = require("@opentelemetry/sdk-logs");
const { PrismaInstrumentation } = require("@prisma/instrumentation");
const { diag, DiagConsoleLogger, DiagLogLevel } = require("@opentelemetry/api");

if (process.env.OTEL_DIAG_LOG_LEVEL) {
    diag.setLogger(new DiagConsoleLogger(), DiagLogLevel[process.env.OTEL_DIAG_LOG_LEVEL] ?? DiagLogLevel.INFO);
}

const sdk = new NodeSDK({
    traceExporter: new OTLPTraceExporter(),
    metricReader: new PeriodicExportingMetricReader({
        exporter: new OTLPMetricExporter(),
        exportIntervalMillis: 30000,
    }),
    logRecordProcessors: [new BatchLogRecordProcessor(new OTLPLogExporter())],
    instrumentations: [
        getNodeAutoInstrumentations({
            // Noisy and of no value here.
            "@opentelemetry/instrumentation-fs": { enabled: false },
            "@opentelemetry/instrumentation-dns": { enabled: false },
            "@opentelemetry/instrumentation-net": { enabled: false },
            // Keep health checks out of the latency/throughput numbers.
            "@opentelemetry/instrumentation-http": {
                ignoreIncomingRequestHook: (req) => req.url === "/healthz",
            },
            // Bridges winston -> OTel logs so app logs carry trace context.
            "@opentelemetry/instrumentation-winston": { enabled: true },
        }),
        // Prisma runs queries in its Rust engine, so pg instrumentation cannot
        // see them; this emits the real database spans instead.
        new PrismaInstrumentation(),
    ],
});

sdk.start();

const shutdown = () => {
    sdk.shutdown()
        .catch((err) => console.error("OpenTelemetry shutdown failed", err))
        .finally(() => process.exit(0));
};

process.once("SIGTERM", shutdown);
process.once("SIGINT", shutdown);

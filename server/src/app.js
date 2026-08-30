const express = require("express");
const app = express();
const router = express.Router();
const cors = require("cors");
const dotenv = require("dotenv");
const HTTP_STATUS = require("./constants/httpStatus");
const prisma = require("./config/database");
const logger = require("./logger");
const accessLog = require("./middleware/accessLog");
dotenv.config();
app.use(cors());
app.use(accessLog);

// Liveness/readiness probe. Excluded from access logs and from the APM
// latency/throughput numbers so it does not dilute real traffic.
app.get("/healthz", async (req, res) => {
    try {
        await prisma.$queryRaw`SELECT 1`;
        return res.status(HTTP_STATUS.OK).send({ status: "ok", database: "up" });
    } catch (error) {
        logger.error("Health check failed", { err: error.message });
        return res.status(HTTP_STATUS.SERVICE_UNAVAILABLE).send({ status: "degraded", database: "down" });
    }
});

router.get("/users/all", async (req, res) => {
    try {
        logger.info("All users request hit", { handler: "users.list" });
        let { page, limit } = req.query;

        if (!page && !limit) {
            page = 1;
            limit = 5;
        }

        if (page <= 0) {
            return res.status(HTTP_STATUS.UNPROCESSABLE_ENTITY).send({
                success: false,
                message: "Page value must be 1 or more",
                data: null,
            });
        }

        if (limit <= 0) {
            return res.status(HTTP_STATUS.UNPROCESSABLE_ENTITY).send({
                success: false,
                message: "Limit value must be 1 or more",
                data: null,
            });
        }

        const users = await prisma.user.findMany({
            skip: Number(page - 1) * Number(limit),
            take: Number(limit),
        });

        const total = await prisma.user.count();
        return res.status(HTTP_STATUS.OK).send({
            success: true,
            message: "Successfully received all users",
            data: {
                users: users,
                total: total,
            },
        });
    } catch (error) {
        logger.error("Failed to list users", { handler: "users.list", err: error });
        return res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).send({
            success: false,
            message: "Internal server error",
        });
    }
});

router.get(`/user/:id`, async (req, res) => {
    try {
        logger.info("Single user request hit", { handler: "users.get" });
        const { id } = req.params;

        const result = await prisma.user.findFirst({ where: { id: Number(id) } });

        if (result) {
            return res.status(HTTP_STATUS.OK).send({
                success: true,
                message: `Successfully received user with id: ${id}`,
                data: result,
            });
        }
        return res.status(HTTP_STATUS.NOT_FOUND).send({
            success: false,
            message: "Could not find user",
            data: null,
        });
    } catch (error) {
        logger.error("Failed to fetch user", { handler: "users.get", err: error });
        return res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).send({
            success: false,
            message: "Internal server error",
        });
    }
});

// Deliberate failure endpoint, used to exercise the error-rate panels and
// alerting. Disabled unless ENABLE_DEBUG_ROUTES=true - keep it off outside dev.
if (process.env.ENABLE_DEBUG_ROUTES === "true") {
    router.get("/debug/error", () => {
        throw new Error("Synthetic failure from /debug/error");
    });
}

app.use("/", router);

// Central error handler: without this Express swallows the stack and the span
// is never marked as failed, so the error rate stays flat during real outages.
app.use((err, req, res, next) => {
    logger.error("Unhandled request error", { err, path: req.originalUrl });
    if (res.headersSent) {
        return next(err);
    }
    return res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).send({
        success: false,
        message: "Internal server error",
    });
});

const server = app.listen(process.env.PORT, () => {
    logger.info("Server started", {
        port: Number(process.env.PORT),
        env: process.env.NODE_ENV || "development",
    });
});

// Graceful shutdown so in-flight spans and log batches get flushed.
for (const signal of ["SIGTERM", "SIGINT"]) {
    process.once(signal, () => {
        logger.info("Shutting down", { signal });
        server.close(() => process.exit(0));
    });
}

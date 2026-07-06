import express from "express";
import cors from "cors";
import { initDb } from "./db.js";
import { router as ordersRouter } from "./routes/orders.js";

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

// ALB target group health check (unauthenticated)
app.get("/health", (_req, res) => res.status(200).send("ok"));

// Matches the ALB listener rule for path pattern /orders/*
app.use("/orders", ordersRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

async function start() {
  try {
    await initDb();
    console.log("Database ready");
  } catch (err) {
    console.error("DB init failed, starting anyway — health check will still respond", err);
  }
  app.listen(PORT, () => console.log(`order-service listening on :${PORT}`));
}

start();

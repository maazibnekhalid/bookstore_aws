import express from "express";
import cors from "cors";
import { initDb } from "./db.js";
import { router as productsRouter } from "./routes/products.js";

const app = express();
const PORT = process.env.PORT || 8080;

app.use(cors());
app.use(express.json());

// ALB target group health check
app.get("/health", (_req, res) => res.status(200).send("ok"));

// Matches the ALB listener rule for path pattern /products/*
app.use("/products", productsRouter);

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
  app.listen(PORT, () => console.log(`product-service listening on :${PORT}`));
}

start();

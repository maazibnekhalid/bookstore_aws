import { Router } from "express";
import { pool } from "../db.js";
import { publishOrderCreated } from "../sqs.js";
import { requireAuth } from "../auth.js";

export const router = Router();
router.use(requireAuth);

// POST /orders  { items: [{ product_id, title, price, quantity }] }
// Writes the order as PENDING, then hands it off asynchronously to SQS ->
// the order-processing Lambda, which updates status once processed.
router.post("/", async (req, res) => {
  const { items } = req.body || {};
  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: "items is required and must be a non-empty array" });
  }

  const total = items.reduce((sum, i) => sum + Number(i.price) * Number(i.quantity || 1), 0);

  try {
    const [result] = await pool.query(
      "INSERT INTO orders (user_sub, user_email, items, total, status) VALUES (?, ?, ?, ?, 'PENDING')",
      [req.user.sub, req.user.email, JSON.stringify(items), total.toFixed(2)]
    );

    const order = { id: result.insertId, user_sub: req.user.sub, items, total: total.toFixed(2), status: "PENDING" };

    await publishOrderCreated(order);

    res.status(201).json(order);
  } catch (err) {
    console.error("Failed to create order", err);
    res.status(500).json({ error: "Failed to create order" });
  }
});

// GET /orders  — current user's order history
router.get("/", async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT * FROM orders WHERE user_sub = ? ORDER BY created_at DESC",
      [req.user.sub]
    );
    res.json({ items: rows });
  } catch (err) {
    console.error("Failed to list orders", err);
    res.status(500).json({ error: "Failed to list orders" });
  }
});

// GET /orders/:id
router.get("/:id", async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT * FROM orders WHERE id = ? AND user_sub = ?",
      [req.params.id, req.user.sub]
    );
    if (rows.length === 0) return res.status(404).json({ error: "Order not found" });
    res.json(rows[0]);
  } catch (err) {
    console.error("Failed to get order", err);
    res.status(500).json({ error: "Failed to get order" });
  }
});

import { Router } from "express";
import { pool } from "../db.js";

export const router = Router();

// GET /products?search=&page=&limit=
router.get("/", async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 20, 100);
  const page = Math.max(Number(req.query.page) || 1, 1);
  const offset = (page - 1) * limit;
  const search = (req.query.search || "").trim();

  try {
    let rows;
    if (search) {
      const like = `%${search}%`;
      [rows] = await pool.query(
        "SELECT * FROM products WHERE title LIKE ? OR author LIKE ? ORDER BY id LIMIT ? OFFSET ?",
        [like, like, limit, offset]
      );
    } else {
      [rows] = await pool.query(
        "SELECT * FROM products ORDER BY id LIMIT ? OFFSET ?",
        [limit, offset]
      );
    }
    res.json({ items: rows, page, limit });
  } catch (err) {
    console.error("Failed to list products", err);
    res.status(500).json({ error: "Failed to list products" });
  }
});

// GET /products/:id
router.get("/:id", async (req, res) => {
  try {
    const [rows] = await pool.query("SELECT * FROM products WHERE id = ?", [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: "Product not found" });
    res.json(rows[0]);
  } catch (err) {
    console.error("Failed to get product", err);
    res.status(500).json({ error: "Failed to get product" });
  }
});

// POST /products  (simple admin create — protect with your own auth/authorization as needed)
router.post("/", async (req, res) => {
  const { title, author, price, description, image_url } = req.body || {};
  if (!title || !author || price == null) {
    return res.status(400).json({ error: "title, author, and price are required" });
  }
  try {
    const [result] = await pool.query(
      "INSERT INTO products (title, author, price, description, image_url) VALUES (?, ?, ?, ?, ?)",
      [title, author, price, description || null, image_url || null]
    );
    res.status(201).json({ id: result.insertId, title, author, price, description, image_url });
  } catch (err) {
    console.error("Failed to create product", err);
    res.status(500).json({ error: "Failed to create product" });
  }
});

import mysql from "mysql2/promise";

const {
  DB_HOST,
  DB_PORT = "3306",
  DB_NAME = "bookstore",
  DB_USER,
  DB_PASSWORD,
} = process.env;

export const pool = mysql.createPool({
  host: DB_HOST,
  port: Number(DB_PORT),
  user: DB_USER,
  password: DB_PASSWORD,
  database: DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

const SEED_PRODUCTS = [
  ["The Pragmatic Bookshelf", "A. Developer", 24.99, "A practical guide to shipping software.", "https://placehold.co/300x400?text=Book"],
  ["Clouds Over Infrastructure", "T. Fargate", 19.5, "A tale of containers, queues, and clusters.", "https://placehold.co/300x400?text=Book"],
  ["The Queue Keeper", "S. Q. Ess", 15.0, "Short stories about messages that always arrive.", "https://placehold.co/300x400?text=Book"],
  ["Aurora Rising", "M. Reader", 29.99, "An epic of writers, readers, and replication.", "https://placehold.co/300x400?text=Book"],
];

export async function initDb() {
  const conn = await pool.getConnection();
  try {
    await conn.query(`
      CREATE TABLE IF NOT EXISTS products (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        author VARCHAR(255) NOT NULL,
        price DECIMAL(10,2) NOT NULL,
        description TEXT,
        image_url VARCHAR(1024),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    const [rows] = await conn.query("SELECT COUNT(*) as count FROM products");
    if (rows[0].count === 0) {
      for (const p of SEED_PRODUCTS) {
        await conn.query(
          "INSERT INTO products (title, author, price, description, image_url) VALUES (?, ?, ?, ?, ?)",
          p
        );
      }
      console.log(`Seeded ${SEED_PRODUCTS.length} products`);
    }
  } finally {
    conn.release();
  }
}

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

export async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS orders (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_sub VARCHAR(64) NOT NULL,
      user_email VARCHAR(255),
      items JSON NOT NULL,
      total DECIMAL(10,2) NOT NULL,
      status VARCHAR(32) NOT NULL DEFAULT 'PENDING',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  `);
}

import { config } from "./config.js";

async function request(path, { method = "GET", body, idToken } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (idToken) headers.Authorization = `Bearer ${idToken}`;

  const res = await fetch(`${config.apiBase}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    const payload = await res.json().catch(() => ({}));
    throw new Error(payload.error || `Request failed (${res.status})`);
  }
  return res.json();
}

// Product Service (public, no auth) — routed by the ALB at /products/*
export const listProducts = (search = "") =>
  request(`/products${search ? `?search=${encodeURIComponent(search)}` : ""}`);

// Order Service (requires Cognito JWT) — routed by the ALB at /orders/*
export const createOrder = (items, idToken) =>
  request("/orders", { method: "POST", body: { items }, idToken });

export const listOrders = (idToken) => request("/orders", { idToken });

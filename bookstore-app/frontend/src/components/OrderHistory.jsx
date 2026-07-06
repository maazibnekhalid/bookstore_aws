import { useEffect, useState } from "react";
import { listOrders } from "../lib/api.js";

export default function OrderHistory({ idToken, refreshKey }) {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    listOrders(idToken)
      .then((data) => !cancelled && setOrders(data.items || []))
      .catch((err) => !cancelled && setError(err.message))
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [idToken, refreshKey]);

  if (loading) return <p className="empty-state">Loading your order history…</p>;
  if (error) return <p className="error-text">{error}</p>;
  if (orders.length === 0) return <p className="empty-state">No orders yet — your first order will appear here.</p>;

  return (
    <section>
      <p className="section-title">Order history</p>
      {orders.map((o) => (
        <div className="order-card" key={o.id}>
          <div>
            <div className="order-id">Order #{o.id} &middot; {new Date(o.created_at).toLocaleDateString()}</div>
            <div>{o.items.length} title(s) &middot; ${Number(o.total).toFixed(2)}</div>
          </div>
          <span className={`status-pill ${o.status}`}>{o.status}</span>
        </div>
      ))}
    </section>
  );
}

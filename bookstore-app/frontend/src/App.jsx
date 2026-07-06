import { useEffect, useState } from "react";
import AuthScreen from "./components/AuthScreen.jsx";
import Catalog from "./components/Catalog.jsx";
import Ledger from "./components/Ledger.jsx";
import OrderHistory from "./components/OrderHistory.jsx";
import { getCurrentSession, logout } from "./lib/auth.js";
import { createOrder } from "./lib/api.js";

export default function App() {
  const [session, setSession] = useState(undefined); // undefined = checking, null = signed out
  const [view, setView] = useState("catalog"); // catalog | history
  const [cart, setCart] = useState([]);
  const [checkingOut, setCheckingOut] = useState(false);
  const [toast, setToast] = useState("");
  const [ordersRefresh, setOrdersRefresh] = useState(0);

  useEffect(() => {
    getCurrentSession().then(setSession);
  }, []);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(""), 3000);
    return () => clearTimeout(t);
  }, [toast]);

  function addToCart(product) {
    setCart((prev) => {
      const existing = prev.find((i) => i.id === product.id);
      if (existing) {
        return prev.map((i) => (i.id === product.id ? { ...i, quantity: i.quantity + 1 } : i));
      }
      return [...prev, { id: product.id, title: product.title, price: Number(product.price), quantity: 1 }];
    });
    setToast(`Added "${product.title}" to your ledger`);
  }

  function changeQty(id, quantity) {
    setCart((prev) =>
      quantity <= 0 ? prev.filter((i) => i.id !== id) : prev.map((i) => (i.id === id ? { ...i, quantity } : i))
    );
  }

  async function checkout() {
    setCheckingOut(true);
    try {
      const items = cart.map((i) => ({ product_id: i.id, title: i.title, price: i.price, quantity: i.quantity }));
      await createOrder(items, session.idToken);
      setCart([]);
      setToast("Order placed — it's on its way to processing");
      setOrdersRefresh((n) => n + 1);
      setView("history");
    } catch (err) {
      setToast(err.message || "Could not place the order");
    } finally {
      setCheckingOut(false);
    }
  }

  if (session === undefined) return null; // brief check on load, avoids a flash of the login form
  if (!session) return <AuthScreen onAuthenticated={setSession} />;

  return (
    <div className="app-shell">
      <header className="site-header">
        <div className="site-mark">
          Fernbank &amp; Co.
          <small>Books by post</small>
        </div>
        <div className="header-actions">
          <button className="link-btn" onClick={() => setView("catalog")}>Catalog</button>
          <button className="link-btn" onClick={() => setView("history")}>Orders</button>
          <span className="cart-count">{cart.reduce((n, i) => n + i.quantity, 0)} in ledger</span>
          <button
            className="link-btn"
            onClick={() => {
              logout();
              setSession(null);
            }}
          >
            Log out
          </button>
        </div>
      </header>

      {view === "catalog" && (
        <>
          <Catalog onAddToCart={addToCart} />
          <Ledger items={cart} onChangeQty={changeQty} onCheckout={checkout} checkingOut={checkingOut} />
        </>
      )}

      {view === "history" && <OrderHistory idToken={session.idToken} refreshKey={ordersRefresh} />}

      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

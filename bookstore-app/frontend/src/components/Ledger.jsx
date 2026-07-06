export default function Ledger({ items, onChangeQty, onCheckout, checkingOut }) {
  const total = items.reduce((sum, i) => sum + i.price * i.quantity, 0);

  return (
    <div className="ledger">
      <h2>Your order</h2>
      <span className="stamp">Ledger &middot; {items.length} title{items.length === 1 ? "" : "s"}</span>

      {items.length === 0 && <p className="empty-state" style={{ padding: "20px 0" }}>Your ledger is empty. Add a book to begin.</p>}

      {items.map((item) => (
        <div className="ledger-row" key={item.id}>
          <span>{item.title}</span>
          <div className="qty-controls">
            <button onClick={() => onChangeQty(item.id, item.quantity - 1)} aria-label={`Decrease quantity of ${item.title}`}>
              −
            </button>
            <span>{item.quantity}</span>
            <button onClick={() => onChangeQty(item.id, item.quantity + 1)} aria-label={`Increase quantity of ${item.title}`}>
              +
            </button>
          </div>
          <span>${(item.price * item.quantity).toFixed(2)}</span>
        </div>
      ))}

      {items.length > 0 && (
        <>
          <div className="ledger-total">
            <span>Total</span>
            <span>${total.toFixed(2)}</span>
          </div>
          <button className="primary-btn" onClick={onCheckout} disabled={checkingOut} style={{ marginTop: 16 }}>
            {checkingOut ? "Placing order…" : "Place order"}
          </button>
        </>
      )}
    </div>
  );
}

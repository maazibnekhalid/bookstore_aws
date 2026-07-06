import { useEffect, useState } from "react";
import { listProducts } from "../lib/api.js";

export default function Catalog({ onAddToCart }) {
  const [products, setProducts] = useState([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const timer = setTimeout(() => fetchProducts(search), 250);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  async function fetchProducts(q) {
    setLoading(true);
    setError("");
    try {
      const data = await listProducts(q);
      setProducts(data.items || []);
    } catch (err) {
      setError(err.message || "Could not load the catalog");
    } finally {
      setLoading(false);
    }
  }

  return (
    <section>
      <div className="toolbar">
        <p className="section-title">The catalog</p>
        <input
          type="search"
          placeholder="Search by title or author…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {error && <p className="error-text">{error}</p>}
      {loading && <p className="empty-state">Fetching titles…</p>}
      {!loading && products.length === 0 && !error && (
        <p className="empty-state">No titles match that search.</p>
      )}

      <div className="catalog-grid">
        {products.map((p) => (
          <article className="catalog-card" key={p.id}>
            <img className="cover" src={p.image_url} alt={`Cover of ${p.title}`} loading="lazy" />
            <div className="card-body">
              <h3 className="title">{p.title}</h3>
              <p className="author">{p.author}</p>
              <div className="price">
                <span>${Number(p.price).toFixed(2)}</span>
                <button className="add-btn" onClick={() => onAddToCart(p)}>
                  Add
                </button>
              </div>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}

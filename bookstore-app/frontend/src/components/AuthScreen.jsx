import { useState } from "react";
import { signUp, confirmSignUp, login } from "../lib/auth.js";

const MODES = { LOGIN: "login", SIGNUP: "signup", CONFIRM: "confirm" };

export default function AuthScreen({ onAuthenticated }) {
  const [mode, setMode] = useState(MODES.LOGIN);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      if (mode === MODES.LOGIN) {
        const session = await login(email, password);
        onAuthenticated(session);
      } else if (mode === MODES.SIGNUP) {
        await signUp(email, password);
        setMode(MODES.CONFIRM);
      } else if (mode === MODES.CONFIRM) {
        await confirmSignUp(email, code);
        const session = await login(email, password);
        onAuthenticated(session);
      }
    } catch (err) {
      setError(err.message || "Something went wrong");
    } finally {
      setBusy(false);
    }
  }

  const copy = {
    [MODES.LOGIN]: { title: "Welcome back", sub: "Log in to pick up where you left off.", cta: "Log in" },
    [MODES.SIGNUP]: { title: "Open an account", sub: "Takes about a minute.", cta: "Sign up" },
    [MODES.CONFIRM]: {
      title: "Check your email",
      sub: `We sent a verification code to ${email}.`,
      cta: "Confirm account",
    },
  }[mode];

  return (
    <div className="auth-wrap">
      <h1>{copy.title}</h1>
      <p className="sub">{copy.sub}</p>

      <form onSubmit={handleSubmit}>
        {mode !== MODES.CONFIRM && (
          <>
            <div className="field">
              <label htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div className="field">
              <label htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                autoComplete={mode === MODES.LOGIN ? "current-password" : "new-password"}
                required
                minLength={8}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
          </>
        )}

        {mode === MODES.CONFIRM && (
          <div className="field">
            <label htmlFor="code">Verification code</label>
            <input id="code" type="text" required value={code} onChange={(e) => setCode(e.target.value)} />
          </div>
        )}

        {error && <p className="error-text">{error}</p>}

        <button className="primary-btn" type="submit" disabled={busy}>
          {busy ? "Working…" : copy.cta}
        </button>
      </form>

      {mode === MODES.LOGIN && (
        <p className="switch-mode">
          New here?{" "}
          <button className="link-btn" onClick={() => setMode(MODES.SIGNUP)}>
            Create an account
          </button>
        </p>
      )}
      {mode === MODES.SIGNUP && (
        <p className="switch-mode">
          Already registered?{" "}
          <button className="link-btn" onClick={() => setMode(MODES.LOGIN)}>
            Log in
          </button>
        </p>
      )}
    </div>
  );
}

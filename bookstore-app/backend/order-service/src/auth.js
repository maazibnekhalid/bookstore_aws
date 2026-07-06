import { CognitoJwtVerifier } from "aws-jwt-verify";

const { COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID } = process.env;

// Verifies the "Authenticated Requests (JWT)" step from the architecture diagram.
// Tokens are issued by the Cognito User Pool after Sign Up / Login on the frontend.
const verifier = COGNITO_USER_POOL_ID
  ? CognitoJwtVerifier.create({
      userPoolId: COGNITO_USER_POOL_ID,
      tokenUse: "id",
      clientId: COGNITO_CLIENT_ID,
    })
  : null;

export async function requireAuth(req, res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: "Missing bearer token" });
  }

  if (!verifier) {
    console.warn("COGNITO_USER_POOL_ID not set — skipping JWT verification (dev mode only)");
    req.user = { sub: "dev-user", email: "dev@example.com" };
    return next();
  }

  try {
    const payload = await verifier.verify(token);
    req.user = { sub: payload.sub, email: payload.email };
    next();
  } catch (err) {
    console.error("JWT verification failed", err.message);
    res.status(401).json({ error: "Invalid or expired token" });
  }
}

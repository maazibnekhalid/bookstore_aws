// All values come from a .env file at build time (see .env.example).
// api_base should be your ALB DNS name / domain, e.g. https://api.yourdomain.com
// (or the plain ALB DNS name if you're testing without a custom domain/HTTPS).
export const config = {
  apiBase: import.meta.env.VITE_API_BASE_URL || "",
  cognito: {
    userPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID || "",
    clientId: import.meta.env.VITE_COGNITO_CLIENT_ID || "",
  },
};

import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
  CognitoUserAttribute,
} from "amazon-cognito-identity-js";
import { config } from "./config.js";

const pool = new CognitoUserPool({
  UserPoolId: config.cognito.userPoolId,
  ClientId: config.cognito.clientId,
});

// Step 1 (Sign Up): create an account with email + password.
export function signUp(email, password) {
  return new Promise((resolve, reject) => {
    pool.signUp(
      email,
      password,
      [new CognitoUserAttribute({ Name: "email", Value: email })],
      null,
      (err, result) => (err ? reject(err) : resolve(result))
    );
  });
}

export function confirmSignUp(email, code) {
  return new Promise((resolve, reject) => {
    const user = new CognitoUser({ Username: email, Pool: pool });
    user.confirmRegistration(code, true, (err, result) => (err ? reject(err) : resolve(result)));
  });
}

// Step 1/2 (Login -> JWT Token): authenticate and return the ID token used
// as the Bearer token on "Authenticated Requests (JWT)" to the Order Service.
export function login(email, password) {
  return new Promise((resolve, reject) => {
    const user = new CognitoUser({ Username: email, Pool: pool });
    const authDetails = new AuthenticationDetails({ Username: email, Password: password });

    user.authenticateUser(authDetails, {
      onSuccess: (session) => {
        resolve({
          idToken: session.getIdToken().getJwtToken(),
          email,
        });
      },
      onFailure: (err) => reject(err),
    });
  });
}

export function logout() {
  const user = pool.getCurrentUser();
  if (user) user.signOut();
}

// Restores a session on page load (step 3: "Access App") if a valid Cognito
// session is already cached in the browser.
export function getCurrentSession() {
  return new Promise((resolve) => {
    const user = pool.getCurrentUser();
    if (!user) return resolve(null);

    user.getSession((err, session) => {
      if (err || !session || !session.isValid()) return resolve(null);
      resolve({
        idToken: session.getIdToken().getJwtToken(),
        email: session.getIdToken().payload.email,
      });
    });
  });
}

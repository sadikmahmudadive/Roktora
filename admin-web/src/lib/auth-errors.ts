/** Turns a Firebase Auth error into a message a person can act on. Returns "" when they just backed out. */
export function authMessage(error: unknown, fallback = "Couldn't sign you in. Try again."): string {
  const code = typeof error === "object" && error !== null && "code" in error ? String((error as { code: unknown }).code) : "";
  switch (code) {
    case "auth/invalid-email":
      return "That email address looks invalid.";
    case "auth/user-not-found":
    case "auth/wrong-password":
    case "auth/invalid-credential":
    case "auth/invalid-login-credentials":
      return "Email or password is incorrect.";
    case "auth/email-already-in-use":
      return "An account with this email already exists. Sign in instead, or reset your password.";
    case "auth/weak-password":
      return "Choose a stronger password: at least 6 characters.";
    case "auth/user-disabled":
      return "This account has been disabled. Contact a Roktora admin.";
    case "auth/too-many-requests":
      return "Too many attempts. Wait a few minutes and try again.";
    case "auth/network-request-failed":
      return "No connection. Check your internet and try again.";
    case "auth/account-exists-with-different-credential":
      return "This email is already registered with another sign-in method. Use that method instead.";
    case "auth/operation-not-allowed":
      return "This sign-in method isn't enabled in Firebase yet.";
    case "auth/unauthorized-domain":
      return "This website's domain isn't authorised in Firebase (Authentication → Settings → Authorized domains).";
    case "auth/popup-blocked":
      return "Your browser blocked the Google sign-in window. Allow pop-ups for this site and try again.";
    case "auth/popup-closed-by-user":
    case "auth/cancelled-popup-request":
      return "";
    default:
      return fallback;
  }
}

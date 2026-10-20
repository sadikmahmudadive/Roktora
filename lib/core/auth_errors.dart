import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Turns a sign-in failure into something a person can act on. Returns an empty string when
/// the user simply backed out (nothing to show).
String authErrorMessage(Object e, {String fallback = "Couldn't sign you in. Try again."}) {
  if (e is FirebaseAuthException) {
    final detail = kDebugMode ? ' [${e.code}]' : '';
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.$detail';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Email or password is incorrect.$detail';
      case 'email-already-in-use':
        return 'An account with this email already exists. Sign in instead, or reset your password.$detail';
      case 'weak-password':
        return 'Choose a stronger password: at least 6 characters.$detail';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.$detail';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.$detail';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.$detail';
      case 'account-exists-with-different-credential':
        return 'This email is already registered with another sign-in method. Use that method instead.$detail';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled for the project yet.$detail';
      case 'web-context-canceled':
      case 'canceled':
      case 'cancelled':
      case 'popup-closed-by-user':
        return '';
    }
    return '$fallback$detail';
  }
  return fallback;
}

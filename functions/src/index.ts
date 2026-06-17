/**
 * functions/src/index.ts - Nexus Firebase Cloud Functions
 *
 * Deploy: cd functions && npm run build && firebase deploy --only functions
 *
 * Exports:
 *   onNotificationCreated - Firestore trigger, sends FCM push
 *   resetPasswordViaPhone - Callable, resets password after OTP verification
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db        = admin.firestore();
const messaging = admin.messaging();

// ---------------------------------------------------------------------------
// onNotificationCreated
// ---------------------------------------------------------------------------

export const onNotificationCreated = functions
  .region('us-central1')
  .firestore.document('users/{uid}/notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const uid  = context.params.uid as string;

    let fcmToken: string | undefined;
    try {
      const userSnap = await db.collection('users').doc(uid).get();
      fcmToken = userSnap.data()?.fcmToken as string | undefined;
    } catch (err) {
      functions.logger.error('Failed to fetch user ' + uid, err);
      return;
    }

    if (!fcmToken) {
      functions.logger.info('No FCM token for user ' + uid);
      return;
    }

    const title: string = data.title ?? 'Nexus';
    const body: string  = data.body  ?? '';
    const type: string  = data.type  ?? 'general';
    const route: string = data.route ?? '/dashboard';

    try {
      await messaging.send({
        token: fcmToken,
        notification: { title, body },
        data: { route, type },
        android: {
          priority: 'high',
          notification: { channelId: 'nexus_push_channel', priority: 'high', defaultSound: true },
        },
        apns: {
          payload: { aps: { sound: 'default', badge: 1, contentAvailable: true } },
          headers: { 'apns-priority': '10' },
        },
      });
      functions.logger.info('FCM sent to ' + uid + ' type=' + type);
    } catch (err) {
      functions.logger.error('FCM failed for ' + uid, err);
      if (isInvalidTokenError(err)) {
        await db.collection('users').doc(uid)
          .update({ fcmToken: admin.firestore.FieldValue.delete() });
      }
    }
  });

// ---------------------------------------------------------------------------
// resetPasswordViaPhone
//
// Security:
//   - context.auth enforced (unauthenticated callers rejected)
//   - context.auth.token.phone_number set by Firebase after OTP (not forgeable)
//   - accountRecovery queried server-side via Admin SDK
//   - admin.auth().updateUser() updates the email/password account UID
// ---------------------------------------------------------------------------

export const resetPasswordViaPhone = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {

    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Phone OTP required.');
    }

    const verifiedPhone = context.auth.token.phone_number as string | undefined;
    if (!verifiedPhone) {
      throw new functions.https.HttpsError('failed-precondition', 'No verified phone number.');
    }

    const payload     = data as Record<string, unknown>;
    const newPassword = ((payload.newPassword as string) ?? '').trim();
    if (newPassword.length < 6) {
      throw new functions.https.HttpsError('invalid-argument', 'Password must be at least 6 characters.');
    }

    const phoneKey     = verifiedPhone.replace(/\D/g, '');
    const recoverySnap = await db.collection('accountRecovery').doc(phoneKey).get();

    if (!recoverySnap.exists) {
      throw new functions.https.HttpsError('not-found', 'No account linked to this phone number.');
    }

    const recoveryData = recoverySnap.data() as Record<string, unknown>;
    const uid          = recoveryData.uid as string | undefined;
    if (!uid) {
      throw new functions.https.HttpsError('internal', 'Incomplete account data.');
    }

    await admin.auth().updateUser(uid, { password: newPassword });
    functions.logger.info('Password reset: uid=' + uid + ' phone=' + verifiedPhone);

    const email = (recoveryData.email as string | undefined) ?? '';
    return { success: true, email };
  });

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function isInvalidTokenError(err: unknown): boolean {
  if (err && typeof err === 'object' && 'errorInfo' in err) {
    const info = (err as { errorInfo?: { code?: string } }).errorInfo;
    const code = info?.code ?? '';
    return code === 'messaging/invalid-registration-token'
        || code === 'messaging/registration-token-not-registered';
  }
  return false;
}

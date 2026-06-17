"use strict";
/**
 * functions/src/index.ts - Nexus Firebase Cloud Functions
 *
 * Deploy: cd functions && npm run build && firebase deploy --only functions
 *
 * Exports:
 *   onNotificationCreated - Firestore trigger, sends FCM push
 *   resetPasswordViaPhone - Callable, resets password after OTP verification
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.resetPasswordViaPhone = exports.onNotificationCreated = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
// ---------------------------------------------------------------------------
// onNotificationCreated
// ---------------------------------------------------------------------------
exports.onNotificationCreated = functions
    .region('us-central1')
    .firestore.document('users/{uid}/notifications/{notificationId}')
    .onCreate(async (snap, context) => {
    var _a, _b, _c, _d, _e;
    const data = snap.data();
    const uid = context.params.uid;
    let fcmToken;
    try {
        const userSnap = await db.collection('users').doc(uid).get();
        fcmToken = (_a = userSnap.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
    }
    catch (err) {
        functions.logger.error('Failed to fetch user ' + uid, err);
        return;
    }
    if (!fcmToken) {
        functions.logger.info('No FCM token for user ' + uid);
        return;
    }
    const title = (_b = data.title) !== null && _b !== void 0 ? _b : 'Nexus';
    const body = (_c = data.body) !== null && _c !== void 0 ? _c : '';
    const type = (_d = data.type) !== null && _d !== void 0 ? _d : 'general';
    const route = (_e = data.route) !== null && _e !== void 0 ? _e : '/dashboard';
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
    }
    catch (err) {
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
exports.resetPasswordViaPhone = functions
    .region('us-central1')
    .https.onCall(async (data, context) => {
    var _a, _b;
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Phone OTP required.');
    }
    const verifiedPhone = context.auth.token.phone_number;
    if (!verifiedPhone) {
        throw new functions.https.HttpsError('failed-precondition', 'No verified phone number.');
    }
    const payload = data;
    const newPassword = ((_a = payload.newPassword) !== null && _a !== void 0 ? _a : '').trim();
    if (newPassword.length < 6) {
        throw new functions.https.HttpsError('invalid-argument', 'Password must be at least 6 characters.');
    }
    const phoneKey = verifiedPhone.replace(/\D/g, '');
    const recoverySnap = await db.collection('accountRecovery').doc(phoneKey).get();
    if (!recoverySnap.exists) {
        throw new functions.https.HttpsError('not-found', 'No account linked to this phone number.');
    }
    const recoveryData = recoverySnap.data();
    const uid = recoveryData.uid;
    if (!uid) {
        throw new functions.https.HttpsError('internal', 'Incomplete account data.');
    }
    await admin.auth().updateUser(uid, { password: newPassword });
    functions.logger.info('Password reset: uid=' + uid + ' phone=' + verifiedPhone);
    const email = (_b = recoveryData.email) !== null && _b !== void 0 ? _b : '';
    return { success: true, email };
});
// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function isInvalidTokenError(err) {
    var _a;
    if (err && typeof err === 'object' && 'errorInfo' in err) {
        const info = err.errorInfo;
        const code = (_a = info === null || info === void 0 ? void 0 : info.code) !== null && _a !== void 0 ? _a : '';
        return code === 'messaging/invalid-registration-token'
            || code === 'messaging/registration-token-not-registered';
    }
    return false;
}
//# sourceMappingURL=index.js.map
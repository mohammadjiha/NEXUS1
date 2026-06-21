/**
 * NEXUS Firebase Cloud Functions
 *
 * Deploy: firebase deploy --only functions
 *
 * Exports:
 *   onUserDeleted             - Deletes Auth account when user doc is soft-deleted
 *   onNotificationCreated     - Firestore trigger → sends FCM push
 *   resetPasswordViaPhone     - Callable: reset password after OTP verification
 *   sendSubscriptionReminders - Scheduled daily 08:00 Asia/Amman: expiry + payment reminders
 *   broadcastToAllUsers       - Callable: super-admin sends notification to all users
 */

const functions = require('firebase-functions');
const admin     = require('firebase-admin');

admin.initializeApp();

const db        = admin.firestore();
const messaging = admin.messaging();

// ---------------------------------------------------------------------------
// onUserDeleted — delete Auth account when isDeleted flips to true
// ---------------------------------------------------------------------------

exports.onUserDeleted = functions
  .region('us-central1')
  .firestore.document('users/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();
    const uid    = context.params.uid;

    if (after.deleted === true && before.deleted !== true) {
      try {
        await admin.auth().deleteUser(uid);
        functions.logger.info(`✅ Auth account deleted for uid: ${uid}`);
      } catch (err) {
        functions.logger.warn(`⚠️ Could not delete Auth user ${uid}: ${err.message}`);
      }
    }
    return null;
  });

// ---------------------------------------------------------------------------
// onNotificationCreated — send FCM push when notification doc is created
// ---------------------------------------------------------------------------

exports.onNotificationCreated = functions
  .region('us-central1')
  .firestore.document('users/{uid}/notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const uid  = context.params.uid;

    let fcmToken;
    try {
      const userSnap = await db.collection('users').doc(uid).get();
      fcmToken = userSnap.data() && userSnap.data().fcmToken;
    } catch (err) {
      functions.logger.error('Failed to fetch user ' + uid, err);
      return;
    }

    if (!fcmToken) {
      functions.logger.info('No FCM token for user ' + uid);
      return;
    }

    const title = data.title || 'Nexus';
    const body  = data.body  || '';
    const type  = data.type  || 'general';
    const route = data.route || '/dashboard';

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
// resetPasswordViaPhone — callable: reset password after OTP verification
// ---------------------------------------------------------------------------

exports.resetPasswordViaPhone = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Phone OTP required.');
    }

    const verifiedPhone = context.auth.token.phone_number;
    if (!verifiedPhone) {
      throw new functions.https.HttpsError('failed-precondition', 'No verified phone number.');
    }

    const newPassword = ((data.newPassword) || '').trim();
    if (newPassword.length < 6) {
      throw new functions.https.HttpsError('invalid-argument', 'Password must be at least 6 characters.');
    }

    const phoneKey     = verifiedPhone.replace(/\D/g, '');
    const recoverySnap = await db.collection('accountRecovery').doc(phoneKey).get();

    if (!recoverySnap.exists) {
      throw new functions.https.HttpsError('not-found', 'No account linked to this phone number.');
    }

    const recoveryData = recoverySnap.data();
    const uid          = recoveryData.uid;
    if (!uid) {
      throw new functions.https.HttpsError('internal', 'Incomplete account data.');
    }

    await admin.auth().updateUser(uid, { password: newPassword });
    functions.logger.info('Password reset: uid=' + uid + ' phone=' + verifiedPhone);

    const email = recoveryData.email || '';
    return { success: true, email };
  });

// ---------------------------------------------------------------------------
// sendSubscriptionReminders — scheduled daily at 08:00 Asia/Amman
//
// For each player whose subscriptionEnd falls exactly 3, 2, 1, or 0 days
// from today, writes a notification doc to users/{uid}/notifications/.
// Doc ID is deterministic → onCreate fires only the first time (no duplicates).
// Also sends a payment reminder when amountRemaining > 0.
// ---------------------------------------------------------------------------

exports.sendSubscriptionReminders = functions
  .region('us-central1')
  .pubsub.schedule('0 8 * * *')
  .timeZone('Asia/Amman')
  .onRun(async (_context) => {
    const now   = new Date();
    const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));

    const snap = await db.collection('users').where('role', '==', 'player').get();

    const REMINDER_DAYS = [3, 2, 1, 0];
    const MS_PER_DAY    = 24 * 60 * 60 * 1000;
    const BATCH_LIMIT   = 400;

    let batch   = db.batch();
    let opCount = 0;

    const flush = async () => {
      if (opCount > 0) {
        await batch.commit();
        batch   = db.batch();
        opCount = 0;
      }
    };

    const enqueue = async (ref, data) => {
      batch.set(ref, data);
      opCount++;
      if (opCount >= BATCH_LIMIT) await flush();
    };

    for (const doc of snap.docs) {
      const data = doc.data();
      if (data.isDeleted === true) continue;

      const subEndTs = data.subscriptionEnd;
      if (!subEndTs || typeof subEndTs.toDate !== 'function') continue;

      const subEnd    = subEndTs.toDate();
      const subEndDay = new Date(Date.UTC(subEnd.getUTCFullYear(), subEnd.getUTCMonth(), subEnd.getUTCDate()));
      const daysLeft  = Math.round((subEndDay.getTime() - today.getTime()) / MS_PER_DAY);

      if (!REMINDER_DAYS.includes(daysLeft)) continue;

      const uid        = doc.id;
      const endDateStr = subEnd.toISOString().split('T')[0];
      const notifCol   = db.collection('users').doc(uid).collection('notifications');

      // Expiry reminder
      const firstName = data.firstName || '';
      const lastName  = data.lastName  || '';
      const name      = [firstName, lastName].filter(Boolean).join(' ') || 'عزيزي اللاعب';
      const { title, body } = buildExpiryMessage(daysLeft, name);

      await enqueue(notifCol.doc(`expiry_${daysLeft}d_${endDateStr}`), {
        title,
        body,
        type:      'subscription_reminder',
        route:     '/dashboard',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Payment reminder
      const amountRemaining = Number(data.amountRemaining || 0);
      if (amountRemaining > 0) {
        await enqueue(notifCol.doc(`payment_reminder_${daysLeft}d_${endDateStr}`), {
          title:     '💰 تذكير بالمدفوعات',
          body:      `${name}، لديك مبلغ ${amountRemaining} JD غير مدفوع. يرجى التواصل مع المدرب لإتمام الدفع.`,
          type:      'payment_reminder',
          route:     '/dashboard',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    await flush();
    functions.logger.info(
      `sendSubscriptionReminders: processed ${snap.size} players, today=${today.toISOString()}`
    );
  });

function buildExpiryMessage(daysLeft, name) {
  switch (daysLeft) {
    case 3: return {
      title: '⚠️ اشتراكك ينتهي بعد 3 أيام',
      body:  `${name}، اشتراكك ينتهي بعد 3 أيام. تواصل مع المدرب لتجديده قبل فوات الأوان.`,
    };
    case 2: return {
      title: '⚠️ اشتراكك ينتهي بعد يومين',
      body:  `${name}، تبقّى يومان فقط على انتهاء اشتراكك. جدّد الآن!`,
    };
    case 1: return {
      title: '🔔 اشتراكك ينتهي غداً!',
      body:  `${name}، اشتراكك ينتهي غداً. تواصل مع المدرب فوراً لتجديده.`,
    };
    case 0: return {
      title: '❌ انتهى اشتراكك اليوم',
      body:  `${name}، انتهى اشتراكك اليوم. تواصل مع المدرب لتجديده والاستمرار في تدريبك.`,
    };
    default: return { title: 'تذكير الاشتراك', body: '' };
  }
}

// ---------------------------------------------------------------------------
// broadcastToAllUsers — callable, super-admin only
//
// Fan-out a notification to every non-deleted user in the app.
// Stores a record in `sa_broadcasts` for history.
// ---------------------------------------------------------------------------

exports.broadcastToAllUsers = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be signed in.');
    }

    const callerSnap = await db.collection('users').doc(context.auth.uid).get();
    const callerRole = (callerSnap.data() && callerSnap.data().role) || '';
    const allowed = ['super_admin','superAdmin','SuperAdmin','dev'];
    if (!allowed.includes(callerRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Super admin only.');
    }

    const title = ((data.title) || '').trim();
    const body  = ((data.body)  || '').trim();
    const type  = ((data.type)  || 'broadcast').trim();
    const route = ((data.route) || '/dashboard').trim();

    if (!title || !body) {
      throw new functions.https.HttpsError('invalid-argument', 'title and body required.');
    }

    const usersSnap = await db.collection('users')
      .where('isDeleted', '!=', true)
      .get();

    const BATCH_LIMIT = 400;
    let batch   = db.batch();
    let opCount = 0;
    let sentTo  = 0;

    const flushBroadcast = async () => {
      if (opCount > 0) {
        await batch.commit();
        batch   = db.batch();
        opCount = 0;
      }
    };

    for (const doc of usersSnap.docs) {
      const notifRef = db.collection('users').doc(doc.id)
        .collection('notifications').doc();

      batch.set(notifRef, {
        title,
        body,
        type,
        route,
        read:      false,
        senderId:  context.auth.uid,
        sentBy:    context.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      opCount++;
      sentTo++;

      if (opCount >= BATCH_LIMIT) await flushBroadcast();
    }

    await flushBroadcast();

    await db.collection('sa_broadcasts').add({
      title,
      body,
      type,
      route,
      sentBy:    context.auth.uid,
      sentCount: sentTo,
      sentAt:    admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(
      `broadcastToAllUsers: sent by ${context.auth.uid}, recipients=${sentTo}`
    );

    return { success: true, sentCount: sentTo };
  });

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function isInvalidTokenError(err) {
  if (err && typeof err === 'object' && err.errorInfo) {
    const code = err.errorInfo.code || '';
    return code === 'messaging/invalid-registration-token'
        || code === 'messaging/registration-token-not-registered';
  }
  return false;
}

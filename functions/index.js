/**
 * BabyGuard Cloud Function: fan out FCM alerts.
 *
 * When the Baby Unit writes a doc under `pairs/{pairId}/events/{eventId}`,
 * this trigger reads the pair's parentToken and sends a high-priority
 * push so the Parent Unit can render a full-screen alert.
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

exports.onAlertEvent = onDocumentCreated(
  'pairs/{pairId}/events/{eventId}',
  async (event) => {
    const { pairId } = event.params;
    const evtData = event.data && event.data.data();
    if (!evtData) return;

    const pairSnap = await getFirestore().collection('pairs').doc(pairId).get();
    if (!pairSnap.exists) {
      console.warn(`pair ${pairId} not found`);
      return;
    }
    const pair = pairSnap.data();
    if (pair.parentMuted === true) {
      console.log(`pair ${pairId} is muted by Parent; skipping FCM`);
      return;
    }
    const token = pair.parentToken;
    if (!token) {
      console.warn(`pair ${pairId} has no parentToken yet`);
      return;
    }

    const db = (evtData.db || 0).toFixed(0);

    const message = {
      token,
      notification: {
        title: 'Baby needs you!',
        body: `Loud sound detected (${db} dB)`,
      },
      data: {
        type: 'alert',
        pairId,
        db: String(evtData.db || 0),
      },
      android: {
        priority: 'high',
        ttl: 60_000,
        notification: {
          channelId: 'alert_channel',
          sound: 'default',
          tag: 'babyguard-alert',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
        payload: {
          aps: {
            sound: { name: 'default', critical: 1, volume: 1.0 },
            'interruption-level': 'critical',
            'content-available': 1,
          },
        },
      },
    };

    try {
      const id = await getMessaging().send(message);
      console.log(`sent alert ${id} to pair ${pairId}`);
    } catch (err) {
      console.error('FCM send failed', err);
    }
  }
);

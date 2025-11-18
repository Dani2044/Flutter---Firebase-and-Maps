const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.onAvailabilityChange = functions.database
  .ref('/users/{uid}/available')
  .onWrite(async (change, context) => {
    const uid = context.params.uid;
    const before = change.before.val();
    const after = change.after.val();

    // solo actuar cuando se cambie a true
    if (before === after) return null;
    if (after !== true) return null;

    try {
      // conseguir todos los usuarios y sus tokens
      const usersSnap = await admin.database().ref('/users').once('value');
      const users = usersSnap.val() || {};

      const tokens = [];
      Object.keys(users).forEach((otherUid) => {
        if (otherUid === uid) return; // saltarse el usuario que ya este disponible
        const entry = users[otherUid];
        if (entry && entry.fcmToken) {
          tokens.push(entry.fcmToken);
        }
      });

      if (tokens.length === 0) return null;

      const payload = {
        notification: {
          title: 'Usuario disponible',
          body: 'Un usuario ha activado disponibilidad. Toca para seguirlo.',
        },
        data: {
          trackedUid: uid,
        },
      };

      const response = await admin.messaging().sendToDevice(tokens, payload);
      return response;
    } catch (err) {
      console.error('Error sending availability notifications', err);
      return null;
    }
  });

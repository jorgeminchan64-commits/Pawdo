'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, serverTimestamp } = require('firebase/firestore');

const projectId = 'pawdo-aeda8';
const code = 'ABC123';
const user1 = 'user-one';
const user2 = 'user-two';
const outsider = 'outsider';
let testEnv;

function db(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

describe('Pawdo Firestore Rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'couples', code), { user1, user2, coins: 10, love: 80 });
      await setDoc(doc(adminDb, 'couples', code, 'games', 'ludo'), {
        winnerSide: '', rewardGranted: false,
      });
    });
  });

  after(async () => testEnv.cleanup());

  it('allows both members to read and denies outsiders', async () => {
    await assertSucceeds(getDoc(doc(db(user1), 'couples', code)));
    await assertSucceeds(getDoc(doc(db(user2), 'couples', code)));
    await assertFails(getDoc(doc(db(outsider), 'couples', code)));
  });

  it('revokes former members after a pair is archived', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'couples', code), { status: 'unlinked' });
    });
    await assertFails(getDoc(doc(db(user1), 'couples', code)));
    await assertFails(getDoc(doc(db(user2), 'couples', code)));
  });

  it('denies direct client changes to user2', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'couples', code), { user2: null });
    });
    await assertFails(updateDoc(doc(db(user2), 'couples', code), {
      user2, updatedAt: serverTimestamp(),
    }));
  });

  it('keeps couple creation and profile membership server-only', async () => {
    await assertFails(setDoc(doc(db(user1), 'couples', 'NEW123'), {
      code: 'NEW123', user1, user2: null, coins: 0,
    }));
    await assertFails(setDoc(doc(db(user1), 'users', user1), {
      uid: user1, coupleCode: code,
    }));
    await assertSucceeds(setDoc(doc(db(user1), 'users', user1), {
      uid: user1, name: 'Uno', profileCompleted: true,
    }));
    await assertSucceeds(updateDoc(doc(db(user1), 'users', user1), {
      displayName: 'Uno visible',
      profileTheme: 'lavender',
      birthday: serverTimestamp(),
      relationshipStartDate: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db(user1), 'users', user1), {
      coupleCode: code,
    }));
    await assertFails(updateDoc(doc(db(user1), 'users', user1), {
      pendingCoupleCode: 'NEW123',
    }));
  });

  it('validates editable profile fields and rejects arbitrary personal data', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', user1), {
        uid: user1,
        name: 'Uno',
        profileCompleted: true,
      });
    });
    await assertFails(updateDoc(doc(db(user1), 'users', user1), {
      admin: true,
    }));
    await assertFails(updateDoc(doc(db(user1), 'users', user1), {
      displayName: '',
    }));
    await assertFails(updateDoc(doc(db(user1), 'users', user1), {
      profileTheme: 'unknown',
    }));
    await assertFails(updateDoc(doc(db(user1), 'users', user1), {
      photoStoragePath: `profile_photos/${user2}.jpg`,
    }));
    await assertSucceeds(updateDoc(doc(db(user1), 'users', user1), {
      displayName: 'Nombre seguro',
      photoStoragePath: `profile_photos/${user1}.jpg`,
      updatedAt: serverTimestamp(),
    }));
  });

  it('does not treat a pending invitation as a complete couple', async () => {
    const pendingCode = 'WAIT24';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'couples', pendingCode), {
        code: pendingCode,
        user1,
        user2: null,
        createdBy: user1,
        status: 'pending',
      });
    });

    await assertSucceeds(getDoc(doc(db(user1), 'couples', pendingCode)));
    await assertFails(getDoc(doc(db(user2), 'couples', pendingCode)));
    await assertFails(setDoc(
      doc(db(user1), 'couples', pendingCode, 'chat', 'message'),
      {
        type: 'text', text: 'Todavía no somos pareja', uploadedBy: user1,
        coupleId: pendingCode, createdAt: serverTimestamp(),
        timestamp: serverTimestamp(),
      },
    ));
  });

  it('repairs a legacy partial profile without weakening uid protection', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', user1), {
        online: true, lastSeenAt: serverTimestamp(),
      });
    });

    await assertSucceeds(setDoc(doc(db(user1), 'users', user1), {
      uid: user1,
      name: 'Uno',
      profileCompleted: true,
    }, { merge: true }));

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', user2), {
        online: true, lastSeenAt: serverTimestamp(),
      });
    });
    await assertFails(setDoc(doc(db(user2), 'users', user2), {
      uid: outsider,
      name: 'Dos',
      profileCompleted: true,
    }, { merge: true }));
  });

  it('denies changing user1 or coins while joining', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'couples', code), { user2: null });
    });
    await assertFails(updateDoc(doc(db(user2), 'couples', code), {
      user2, user1: user2, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db(user2), 'couples', code), {
      user2, coins: 999, updatedAt: serverTimestamp(),
    }));
  });

  for (const field of ['coins', 'love']) {
    it(`denies direct member writes to ${field}`, async () => {
      await assertFails(updateDoc(doc(db(user1), 'couples', code), { [field]: 999 }));
    });
  }

  it('denies client winner and reward fields', async () => {
    const game = doc(db(user1), 'couples', code, 'games', 'ludo');
    await assertFails(updateDoc(game, { winnerSide: 'A' }));
    await assertFails(updateDoc(game, { rewardClaimed: true }));
  });

  it('allows members to observe games but keeps all game writes server-only', async () => {
    const game = doc(db(user1), 'couples', code, 'games', 'ludo');
    await assertSucceeds(getDoc(game));
    await assertFails(setDoc(doc(db(user1), 'couples', code, 'games', 'tic_tac_toe'), {
      board: ['', '', '', '', '', '', '', '', ''],
    }));
    await assertFails(updateDoc(game, { turnSide: 'B' }));
  });

  it('denies private game state and reward claims to every client', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'privateGameState', `${code}__movie_guess`), {
        answer: 'Titanic',
      });
      await setDoc(doc(adminDb, 'couples', code, 'gameRewardClaims', 'today_movie'), {
        claimedBy: user1,
      });
    });
    await assertFails(getDoc(doc(db(user1), 'privateGameState', `${code}__movie_guess`)));
    await assertFails(getDoc(doc(db(user2), 'privateGameState', `${code}__movie_guess`)));
    await assertFails(setDoc(doc(db(user1), 'privateGameState', 'forged'), { answer: 'x' }));
    await assertFails(getDoc(doc(db(user1), 'couples', code, 'gameRewardClaims', 'today_movie')));
    await assertFails(setDoc(doc(db(user1), 'couples', code, 'gameRewardClaims', 'forged'), {
      claimedBy: user1,
    }));
  });

  it('keeps all chat creation and deletion server-only', async () => {
    await assertFails(setDoc(doc(db(user1), 'couples', code, 'chat', 'text-1'), {
      type: 'text', text: 'Hola', uploadedBy: user1, coupleId: code,
      createdAt: serverTimestamp(), timestamp: serverTimestamp(),
    }));
    await assertFails(setDoc(doc(db(user1), 'couples', code, 'chat', 'photo-1'), {
      type: 'image', storagePath: `couples/${code}/photos/file.jpg`,
      uploadedBy: user1, coupleCode: code, fileName: 'file.jpg',
      contentType: 'image/jpeg', sizeBytes: 100,
      createdAt: serverTimestamp(), timestamp: serverTimestamp(),
    }));
  });

  it('allows only each member to publish their own typing state', async () => {
    await assertSucceeds(setDoc(
      doc(db(user1), 'couples', code, 'typing', user1),
      { uid: user1, isTyping: true, updatedAt: serverTimestamp() },
    ));
    await assertFails(setDoc(
      doc(db(user1), 'couples', code, 'typing', user2),
      { uid: user2, isTyping: true, updatedAt: serverTimestamp() },
    ));
    await assertFails(setDoc(
      doc(db(outsider), 'couples', code, 'typing', outsider),
      { uid: outsider, isTyping: true, updatedAt: serverTimestamp() },
    ));
  });

  it('protects notification devices and validates preferences', async () => {
    const device = doc(db(user1), 'users', user1, 'devices', 'a'.repeat(64));
    await assertSucceeds(setDoc(device, {
      token: 't'.repeat(30), platform: 'android', enabled: true,
      updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(
      doc(db(user2), 'users', user1, 'devices', 'b'.repeat(64)),
      { token: 'x'.repeat(30), platform: 'android', enabled: true, updatedAt: serverTimestamp() },
    ));
    const settings = doc(db(user1), 'users', user1, 'settings', 'notifications');
    await assertSucceeds(setDoc(settings, {
      chatEnabled: true, quickMessagesEnabled: true,
      hideSensitiveContent: true, quietHoursEnabled: false,
      quietStartHour: 22, quietEndHour: 8, updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(settings, {
      chatEnabled: true, quickMessagesEnabled: true,
      hideSensitiveContent: true, quietHoursEnabled: false,
      quietStartHour: 99, quietEndHour: 8, updatedAt: serverTimestamp(),
    }));
  });

  it('keeps layouts, house selection and inventory server-only', async () => {
    const couple = doc(db(user1), 'couples', code);
    await assertFails(updateDoc(couple, {
      selectedHouseId: 'house_modern_love',
      houseUpdatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(couple, {
      gardenLayout: [{ id: 'forged', asset: 'houses/house_modern_love.png' }],
      gardenRevision: 99,
      gardenUpdatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(couple, {
      interiorLayout: [{ id: 'forged', assetPath: 'interior/bed_romantic.png' }],
      interiorRevision: 99,
      interiorUpdatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(couple, {
      ownedGardenItems: ['house_modern_love'],
      ownedInteriorItems: ['bed_romantic'],
    }));
    await assertFails(updateDoc(couple, {
      gardenPlant: { stage: 3, waterings: 999 },
    }));
  });

  it('lets active members read the economy ledger but never write it', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'couples', code, 'economyLedger', 'purchase_test'),
        { type: 'purchase', deltaCoins: -10, balanceAfter: 0 },
      );
    });
    const memberEntry = doc(db(user1), 'couples', code, 'economyLedger', 'purchase_test');
    await assertSucceeds(getDoc(memberEntry));
    await assertFails(getDoc(doc(db(outsider), 'couples', code, 'economyLedger', 'purchase_test')));
    await assertFails(setDoc(
      doc(db(user1), 'couples', code, 'economyLedger', 'forged'),
      { type: 'reward', deltaCoins: 999999 },
    ));
    await assertFails(updateDoc(memberEntry, { deltaCoins: 999999 }));
  });

  it('denies forged uploadedBy and outsider messages', async () => {
    const message = {
      type: 'image', storagePath: `couples/${code}/photos/file.jpg`,
      uploadedBy: user2, coupleCode: code, fileName: 'file.jpg',
      contentType: 'image/jpeg', sizeBytes: 100,
      createdAt: serverTimestamp(), timestamp: serverTimestamp(),
    };
    await assertFails(setDoc(doc(db(user1), 'couples', code, 'chat', 'forged'), message));
    await assertFails(setDoc(doc(db(outsider), 'couples', code, 'chat', 'outside'), {
      ...message, uploadedBy: outsider,
    }));
  });
});

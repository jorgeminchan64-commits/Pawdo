'use strict';

const assert = require('node:assert/strict');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT || 'pawdo-aeda8';
const code = 'ABC123';
const user1 = 'user-one';
const user2 = 'user-two';
const outsider = 'outsider';

const handlers = require('../index')._test;
const db = getFirestore();

function request(uid, data) {
  return {
    auth: uid ? { uid, token: { email: `${uid}@example.test` } } : null,
    data,
  };
}

async function clearFirestore() {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (!host) throw new Error('FIRESTORE_EMULATOR_HOST is required.');
  const response = await fetch(
    `http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  if (!response.ok) throw new Error(`Could not clear Firestore: ${response.status}`);
}

async function seedCouple() {
  await db.doc(`couples/${code}`).set({
    code, user1, user2, coins: 10, love: 80, energy: 70,
  });
}

async function seedGame(overrides = {}) {
  await db.doc(`couples/${code}/games/ludo`).set({
    gameId: 'ludo',
    players: { A: user1, B: user2 },
    joinedBy: [user1, user2],
    playerNames: { A: 'Uno', B: 'Dos' },
    tokens: { A: [-1, -1, -1, -1], B: [-1, -1, -1, -1] },
    turnSide: 'A', dice: 0, phase: 'roll', winnerSide: '',
    ...overrides,
  });
}

async function rejectsCode(action, codeValue) {
  await assert.rejects(action, (error) => error?.code === codeValue);
}

describe('Pawdo callable security', () => {
  beforeEach(async () => {
    await clearFirestore();
    await seedCouple();
  });

  it('rejects unauthenticated users', async () => {
    await rejectsCode(
      () => handlers.rollLudoDiceHandler(request(null, { coupleCode: code })),
      'unauthenticated',
    );
  });

  it('keeps only the newest invitation without creating a final membership', async () => {
    const creator = 'new-creator';
    await db.doc(`users/${creator}`).set({
      uid: creator,
      email: 'creator@example.test',
      profileCompleted: true,
      relationshipStartDate: new Date('2025-01-01T00:00:00Z'),
    });
    const first = await handlers.createCoupleCodeHandler(request(creator, {}));
    const second = await handlers.createCoupleCodeHandler(request(creator, {}));
    assert.match(second.coupleCode, /^[A-Z0-9]{6}$/);
    assert.notEqual(first.coupleCode, second.coupleCode);

    assert.equal((await db.doc(`couples/${first.coupleCode}`).get()).exists, false);
    const invitation = (await db.doc(`couples/${second.coupleCode}`).get()).data();
    const profile = (await db.doc(`users/${creator}`).get()).data();
    assert.equal(invitation.user1, creator);
    assert.equal(invitation.user2, null);
    assert.equal(invitation.status, 'pending');
    assert.equal(invitation.coins, undefined);
    assert.equal(profile.pendingCoupleCode, second.coupleCode);
    assert.equal(profile.coupleCode, undefined);
  });

  it('cancels new and legacy invitations but never deletes a final pair', async () => {
    const owner = 'cancel-owner';
    await db.doc(`users/${owner}`).set({
      uid: owner, profileCompleted: true,
    });
    const invitation = await handlers.createCoupleCodeHandler(request(owner, {}));
    const cancelled = await handlers.cancelCoupleInvitationHandler(request(owner, {}));
    assert.equal(cancelled.cancelled, true);
    assert.equal((await db.doc(`couples/${invitation.coupleCode}`).get()).exists, false);
    let profile = (await db.doc(`users/${owner}`).get()).data();
    assert.equal(profile.pendingCoupleCode, undefined);

    const legacyCode = 'LEG123';
    await db.doc(`couples/${legacyCode}`).set({
      code: legacyCode, user1: owner, user2: null, createdAt: Timestamp.now(),
    });
    await db.doc(`users/${owner}`).set({ coupleCode: legacyCode }, { merge: true });
    await handlers.cancelCoupleInvitationHandler(request(owner, {}));
    assert.equal((await db.doc(`couples/${legacyCode}`).get()).exists, false);
    profile = (await db.doc(`users/${owner}`).get()).data();
    assert.equal(profile.coupleCode, undefined);

    await db.doc(`users/${user1}`).set({
      uid: user1, profileCompleted: true, coupleCode: code,
    });
    await rejectsCode(
      () => handlers.cancelCoupleInvitationHandler(request(user1, {})),
      'failed-precondition',
    );
    assert.equal((await db.doc(`couples/${code}`).get()).exists, true);
  });

  it('migrates legacy invitations and joins atomically', async () => {
    const joiningUser = 'joining-user';
    await db.doc(`couples/${code}`).update({ user2: null });
    await db.doc(`users/${user1}`).set({
      uid: user1, coupleCode: code, profileCompleted: true,
    });
    const legacyCode = 'OLD123';
    await db.doc(`couples/${legacyCode}`).set({
      code: legacyCode, user1: joiningUser, user2: null,
      createdAt: Timestamp.now(),
    });
    await db.doc(`users/${joiningUser}`).set({
      uid: joiningUser, coupleCode: legacyCode, profileCompleted: true,
    });

    const result = await handlers.joinCoupleHandler(request(joiningUser, {
      coupleCode: code.toLowerCase(),
    }));
    assert.equal(result.joined, true);
    const paired = (await db.doc(`couples/${code}`).get()).data();
    assert.equal(paired.user2, joiningUser);
    assert.equal(paired.status, 'paired');
    assert.equal((await db.doc(`couples/${legacyCode}`).get()).exists, false);
    assert.equal((await db.doc(`users/${user1}`).get()).data().coupleCode, code);
    assert.equal((await db.doc(`users/${joiningUser}`).get()).data().coupleCode, code);
    assert.equal((await db.doc(`users/${joiningUser}`).get()).data().pendingCoupleCode, undefined);
  });

  it('lets two users with invitations pair using either invitation', async () => {
    const inviter = 'inviter-a';
    const joiningUser = 'inviter-b';
    await db.doc(`users/${inviter}`).set({ uid: inviter, profileCompleted: true });
    await db.doc(`users/${joiningUser}`).set({
      uid: joiningUser, profileCompleted: true,
    });
    const invitationA = await handlers.createCoupleCodeHandler(request(inviter, {}));
    const invitationB = await handlers.createCoupleCodeHandler(request(joiningUser, {}));

    await handlers.joinCoupleHandler(request(joiningUser, {
      coupleCode: invitationA.coupleCode,
    }));

    assert.equal((await db.doc(`couples/${invitationB.coupleCode}`).get()).exists, false);
    const pair = (await db.doc(`couples/${invitationA.coupleCode}`).get()).data();
    assert.equal(pair.user1, inviter);
    assert.equal(pair.user2, joiningUser);
    assert.equal(pair.status, 'paired');
  });

  it('creates only one pair when both users join each other concurrently', async () => {
    const firstUser = 'race-a';
    const secondUser = 'race-b';
    await db.doc(`users/${firstUser}`).set({
      uid: firstUser, profileCompleted: true,
    });
    await db.doc(`users/${secondUser}`).set({
      uid: secondUser, profileCompleted: true,
    });
    const firstInvite = await handlers.createCoupleCodeHandler(request(firstUser, {}));
    const secondInvite = await handlers.createCoupleCodeHandler(request(secondUser, {}));

    const attempts = await Promise.allSettled([
      handlers.joinCoupleHandler(request(firstUser, {
        coupleCode: secondInvite.coupleCode,
      })),
      handlers.joinCoupleHandler(request(secondUser, {
        coupleCode: firstInvite.coupleCode,
      })),
    ]);
    assert.equal(attempts.filter((result) => result.status === 'fulfilled').length, 1);

    const [firstDoc, secondDoc, firstProfile, secondProfile] = await Promise.all([
      db.doc(`couples/${firstInvite.coupleCode}`).get(),
      db.doc(`couples/${secondInvite.coupleCode}`).get(),
      db.doc(`users/${firstUser}`).get(),
      db.doc(`users/${secondUser}`).get(),
    ]);
    const remaining = [firstDoc, secondDoc].filter((snapshot) => snapshot.exists);
    assert.equal(remaining.length, 1);
    assert.equal(remaining[0].data().status, 'paired');
    assert.equal(firstProfile.data().coupleCode, secondProfile.data().coupleCode);
    assert.equal(firstProfile.data().pendingCoupleCode, undefined);
    assert.equal(secondProfile.data().pendingCoupleCode, undefined);
  });

  it('unlinks both profiles atomically and archives shared data', async () => {
    await db.doc(`users/${user1}`).set({ uid: user1, profileCompleted: true, coupleCode: code });
    await db.doc(`users/${user2}`).set({ uid: user2, profileCompleted: true, coupleCode: code });
    await db.doc(`couples/${code}/state/pet`).set({ name: 'Pawdo' });

    await rejectsCode(
      () => handlers.unlinkCoupleHandler(request(user1, { confirm: false })),
      'invalid-argument',
    );
    const result = await handlers.unlinkCoupleHandler(request(user1, { confirm: true }));
    assert.equal(result.unlinked, true);

    const [archived, firstProfile, secondProfile, pet] = await Promise.all([
      db.doc(`couples/${code}`).get(), db.doc(`users/${user1}`).get(),
      db.doc(`users/${user2}`).get(), db.doc(`couples/${code}/state/pet`).get(),
    ]);
    assert.equal(archived.data().status, 'unlinked');
    assert.equal(archived.data().unlinkedBy, user1);
    assert.equal(firstProfile.data().coupleCode, undefined);
    assert.equal(secondProfile.data().coupleCode, undefined);
    assert.equal(pet.exists, true);
  });

  it('repairs stale profile membership from the authoritative pair', async () => {
    const repairUser = 'repair-user';
    const repairPartner = 'repair-partner';
    const repairCode = 'FIX123';
    await db.doc(`users/${repairUser}`).set({
      uid: repairUser, profileCompleted: true, coupleCode: 'GONE24', pendingCoupleCode: 'OLD123',
    });
    await db.doc(`users/${repairPartner}`).set({ uid: repairPartner, coupleCode: repairCode });
    await db.doc(`couples/${repairCode}`).set({
      code: repairCode, user1: repairPartner, user2: repairUser, status: 'paired',
    });

    const result = await handlers.repairCoupleMembershipHandler(request(repairUser, {}));
    assert.equal(result.state, 'paired');
    assert.equal(result.coupleCode, repairCode);
    const profile = (await db.doc(`users/${repairUser}`).get()).data();
    assert.equal(profile.coupleCode, repairCode);
    assert.equal(profile.pendingCoupleCode, undefined);
  });

  it('refuses to guess when legacy data contains multiple active pairs', async () => {
    const repairUser = 'duplicate-user';
    await db.doc(`users/${repairUser}`).set({ uid: repairUser, profileCompleted: true });
    await db.doc('couples/DUPL01').set({
      code: 'DUPL01', user1: repairUser, user2: 'partner-a', status: 'paired',
    });
    await db.doc('couples/DUPL02').set({
      code: 'DUPL02', user1: 'partner-b', user2: repairUser, status: 'paired',
    });
    await rejectsCode(
      () => handlers.repairCoupleMembershipHandler(request(repairUser, {})),
      'failed-precondition',
    );
  });

  it('rejects invalid, missing, expired and consumed codes clearly', async () => {
    await rejectsCode(
      () => handlers.joinCoupleHandler(request('invalid-user', { coupleCode: 'BAD' })),
      'invalid-argument',
    );
    await rejectsCode(
      () => handlers.joinCoupleHandler(request('missing-user', { coupleCode: 'MISS24' })),
      'not-found',
    );

    const expiredCode = 'EXP123';
    await db.doc(`couples/${expiredCode}`).set({
      code: expiredCode,
      user1,
      user2: null,
      createdBy: user1,
      status: 'pending',
      inviteExpiresAt: Timestamp.fromMillis(Date.now() - 1000),
    });
    await db.doc(`users/${user1}`).set({ uid: user1, pendingCoupleCode: expiredCode });
    await rejectsCode(
      () => handlers.joinCoupleHandler(request(outsider, { coupleCode: expiredCode })),
      'deadline-exceeded',
    );

    await rejectsCode(
      () => handlers.joinCoupleHandler(request('third-user', { coupleCode: code })),
      'already-exists',
    );
  });

  it('rejects own codes and users that already have a final pair', async () => {
    const owner = 'own-code-user';
    await db.doc(`users/${owner}`).set({ uid: owner, profileCompleted: true });
    const ownInvite = await handlers.createCoupleCodeHandler(request(owner, {}));
    await rejectsCode(
      () => handlers.joinCoupleHandler(request(owner, { coupleCode: ownInvite.coupleCode })),
      'failed-precondition',
    );

    const targetOwner = 'target-owner';
    const pairedUser = 'paired-user';
    await db.doc(`users/${targetOwner}`).set({
      uid: targetOwner, profileCompleted: true,
    });
    const target = await handlers.createCoupleCodeHandler(request(targetOwner, {}));
    await db.doc(`users/${pairedUser}`).set({
      uid: pairedUser, coupleCode: code, profileCompleted: true,
    });
    await rejectsCode(
      () => handlers.joinCoupleHandler(request(pairedUser, { coupleCode: target.coupleCode })),
      'failed-precondition',
    );
    await rejectsCode(
      () => handlers.createCoupleCodeHandler(request(pairedUser, {})),
      'failed-precondition',
    );
  });

  it('rolls back all cleanup when the invitation owner already has a pair', async () => {
    const owner = 'rollback-owner';
    const joiningUser = 'rollback-joiner';
    const targetCode = 'ROLL24';
    const ownCode = 'OWN123';
    await db.doc(`couples/${targetCode}`).set({
      code: targetCode, user1: owner, user2: null, createdBy: owner,
      status: 'pending', inviteExpiresAt: Timestamp.fromMillis(Date.now() + 60000),
    });
    await db.doc('couples/PAIR99').set({
      code: 'PAIR99', user1: owner, user2: 'another-user', status: 'paired',
    });
    await db.doc(`couples/${ownCode}`).set({
      code: ownCode, user1: joiningUser, user2: null, createdBy: joiningUser,
      status: 'pending', inviteExpiresAt: Timestamp.fromMillis(Date.now() + 60000),
    });
    await db.doc(`users/${owner}`).set({
      uid: owner, pendingCoupleCode: targetCode, coupleCode: 'PAIR99',
      profileCompleted: true,
    });
    await db.doc(`users/${joiningUser}`).set({
      uid: joiningUser, pendingCoupleCode: ownCode, profileCompleted: true,
    });

    await rejectsCode(
      () => handlers.joinCoupleHandler(request(joiningUser, { coupleCode: targetCode })),
      'failed-precondition',
    );
    assert.equal((await db.doc(`couples/${targetCode}`).get()).data().status, 'pending');
    assert.equal((await db.doc(`couples/${ownCode}`).get()).exists, true);
    assert.equal((await db.doc(`users/${joiningUser}`).get()).data().coupleCode, undefined);
  });

  it('makes a repeated join to the same pair idempotent', async () => {
    const owner = 'double-owner';
    const joiningUser = 'double-joiner';
    await db.doc(`users/${owner}`).set({ uid: owner, profileCompleted: true });
    await db.doc(`users/${joiningUser}`).set({
      uid: joiningUser, profileCompleted: true,
    });
    const invitation = await handlers.createCoupleCodeHandler(request(owner, {}));
    await handlers.joinCoupleHandler(request(joiningUser, {
      coupleCode: invitation.coupleCode,
    }));
    const repeated = await handlers.joinCoupleHandler(request(joiningUser, {
      coupleCode: invitation.coupleCode,
    }));
    assert.equal(repeated.joined, true);
    assert.equal(repeated.alreadyJoined, true);
  });

  it('refreshes safe member summaries and shared presence', async () => {
    await db.doc(`users/${user1}`).set({
      uid: user1, coupleCode: code, profileCompleted: true,
      name: 'Nombre privado', displayName: 'Uno visible',
      photoStoragePath: `profile_photos/${user1}.jpg`,
    });
    await db.doc(`users/${user2}`).set({
      uid: user2, coupleCode: code, profileCompleted: true,
      name: 'Dos', photoStoragePath: 'profile_photos/not-the-owner.jpg',
    });

    const refreshed = await handlers.refreshCoupleProfilesHandler(request(user1, {}));
    assert.equal(refreshed.refreshed, true);
    let couple = (await db.doc(`couples/${code}`).get()).data();
    assert.equal(couple.memberProfiles[user1].name, 'Uno visible');
    assert.equal(couple.memberProfiles[user1].photoStoragePath, `profile_photos/${user1}.jpg`);
    assert.equal(couple.memberProfiles[user2].photoStoragePath, undefined);

    const presence = await handlers.setCouplePresenceHandler(request(user2, { online: true }));
    assert.equal(presence.updated, true);
    couple = (await db.doc(`couples/${code}`).get()).data();
    assert.equal(couple.memberPresence[user2].online, true);
    assert.equal((await db.doc(`users/${user2}`).get()).data().online, true);
  });

  it('sends chat messages idempotently and rejects forged retries', async () => {
    const messageId = 'chat-message-001';
    const first = await handlers.sendChatMessageHandler(request(user1, {
      coupleCode: code, messageId, text: 'Hola seguro',
    }));
    assert.equal(first.sent, true);
    assert.equal(first.alreadySent, false);
    const repeated = await handlers.sendChatMessageHandler(request(user1, {
      coupleCode: code, messageId, text: 'Hola seguro',
    }));
    assert.equal(repeated.alreadySent, true);
    await rejectsCode(
      () => handlers.sendChatMessageHandler(request(user1, {
        coupleCode: code, messageId, text: 'Contenido distinto',
      })),
      'already-exists',
    );
    const message = (await db.doc(`couples/${code}/chat/${messageId}`).get()).data();
    assert.equal(message.uploadedBy, user1);
    assert.equal(message.text, 'Hola seguro');
    assert.equal(message.schemaVersion, 2);
  });

  it('rate limits bursts and quick-message spam', async () => {
    await handlers.sendChatMessageHandler(request(user1, {
      coupleCode: code, messageId: 'quick-message-001', quickId: 'miss_you',
    }));
    await rejectsCode(
      () => handlers.sendChatMessageHandler(request(user1, {
        coupleCode: code, messageId: 'quick-message-002', quickId: 'love_you',
      })),
      'resource-exhausted',
    );

    await clearFirestore();
    await seedCouple();
    for (let index = 0; index < 12; index += 1) {
      await handlers.sendChatMessageHandler(request(user1, {
        coupleCode: code,
        messageId: `burst-message-${String(index).padStart(3, '0')}`,
        text: `Mensaje ${index}`,
      }));
    }
    await rejectsCode(
      () => handlers.sendChatMessageHandler(request(user1, {
        coupleCode: code, messageId: 'burst-message-999', text: 'Uno de más',
      })),
      'resource-exhausted',
    );
  });

  it('marks reads and lets only the author delete within policy', async () => {
    const messageId = 'read-message-001';
    await handlers.sendChatMessageHandler(request(user1, {
      coupleCode: code, messageId, text: 'Para leer',
    }));
    const read = await handlers.markChatReadHandler(request(user2, {
      coupleCode: code, messageId,
    }));
    assert.equal(read.read, true);
    const couple = (await db.doc(`couples/${code}`).get()).data();
    assert.equal(couple.chatReadState[user2].messageId, messageId);
    await rejectsCode(
      () => handlers.deleteChatMessageHandler(request(user2, {
        coupleCode: code, messageId,
      })),
      'permission-denied',
    );
    const deleted = await handlers.deleteChatMessageHandler(request(user1, {
      coupleCode: code, messageId,
    }));
    assert.equal(deleted.deleted, true);
    assert.equal((await db.doc(`couples/${code}/chat/${messageId}`).get()).exists, false);
  });

  it('rejects delayed chat work after unlinking', async () => {
    await db.doc(`couples/${code}`).update({ status: 'unlinked' });
    await rejectsCode(
      () => handlers.sendChatMessageHandler(request(user1, {
        coupleCode: code, messageId: 'archived-message-01', text: 'No debe salir',
      })),
      'failed-precondition',
    );
    await handlers.notifyCoupleActivityHandler({
      params: { coupleCode: code, messageId: 'delayed-event-01' },
      data: { data: () => ({ uploadedBy: user1, type: 'text' }) },
    });
  });

  it('cleans expired invitations and their profile reference atomically', async () => {
    const owner = 'expired-owner';
    const expiredCode = 'OLD999';
    await db.doc(`couples/${expiredCode}`).set({
      code: expiredCode,
      user1: owner,
      user2: null,
      createdBy: owner,
      status: 'pending',
      inviteExpiresAt: Timestamp.fromMillis(Date.now() - 1000),
    });
    await db.doc(`users/${owner}`).set({
      uid: owner,
      profileCompleted: true,
      pendingCoupleCode: expiredCode,
    });

    const result = await handlers.cleanupExpiredCoupleInvitationsHandler();
    assert.equal(result.deleted, 1);
    assert.equal((await db.doc(`couples/${expiredCode}`).get()).exists, false);
    assert.equal(
      (await db.doc(`users/${owner}`).get()).data().pendingCoupleCode,
      undefined,
    );
  });

  it('rejects users outside the couple', async () => {
    await seedGame();
    await rejectsCode(
      () => handlers.moveLudoTokenHandler(request(outsider, {
        coupleCode: code, tokenIndex: 0,
      })),
      'permission-denied',
    );
  });

  it('rejects a missing match', async () => {
    await rejectsCode(
      () => handlers.moveLudoTokenHandler(request(user1, {
        coupleCode: code, tokenIndex: 0,
      })),
      'not-found',
    );
  });

  it('rejects reset while a match is not finished', async () => {
    await seedGame();
    await rejectsCode(
      () => handlers.resetLudoHandler(request(user1, { coupleCode: code })),
      'failed-precondition',
    );
  });

  it('starts Ludo only after both players join the room', async () => {
    await db.doc(`users/${user1}`).set({ name: 'Uno' });
    await db.doc(`users/${user2}`).set({ name: 'Dos' });
    await handlers.joinLudoHandler(request(user1, { coupleCode: code }));
    let game = (await db.doc(`couples/${code}/games/ludo`).get()).data();
    assert.equal(game.phase, 'waiting');
    assert.deepEqual(game.joinedBy, [user1]);
    await rejectsCode(
      () => handlers.rollLudoDiceHandler(request(user1, { coupleCode: code })),
      'failed-precondition',
    );
    await handlers.joinLudoHandler(request(user2, { coupleCode: code }));
    game = (await db.doc(`couples/${code}/games/ludo`).get()).data();
    assert.equal(game.phase, 'roll');
    assert.deepEqual(new Set(game.joinedBy), new Set([user1, user2]));
  });

  it('requires both votes to restart a finished Ludo match', async () => {
    await seedGame({ phase: 'finished', winnerSide: 'A', round: 1 });
    const first = await handlers.resetLudoHandler(request(user1, { coupleCode: code }));
    assert.equal(first.reset, false);
    let game = (await db.doc(`couples/${code}/games/ludo`).get()).data();
    assert.equal(game.phase, 'finished');
    const second = await handlers.resetLudoHandler(request(user2, { coupleCode: code }));
    assert.equal(second.reset, true);
    game = (await db.doc(`couples/${code}/games/ludo`).get()).data();
    assert.equal(game.phase, 'roll');
    assert.equal(game.round, 2);
  });

  it('finishes an abandoned Ludo match without a reward', async () => {
    await seedGame();
    const result = await handlers.abandonLudoHandler(request(user1, { coupleCode: code }));
    assert.equal(result.abandoned, true);
    assert.equal(result.rewardAwarded, false);
    const game = (await db.doc(`couples/${code}/games/ludo`).get()).data();
    assert.equal(game.phase, 'finished');
    assert.equal(game.abandonedBy, user1);
    assert.equal((await db.doc(`couples/${code}`).get()).data().coins, 10);
  });

  it('rejects a move after an existing winner', async () => {
    await seedGame({ phase: 'finished', winnerSide: 'B' });
    await rejectsCode(
      () => handlers.moveLudoTokenHandler(request(user1, {
        coupleCode: code, tokenIndex: 0,
      })),
      'failed-precondition',
    );
  });

  it('server validates the final move, credits once, and is idempotent', async () => {
    await seedGame({
      tokens: { A: [52, 52, 52, 51], B: [-1, -1, -1, -1] },
      turnSide: 'A', dice: 1, phase: 'choose', winnerSide: '',
    });
    const result = await handlers.moveLudoTokenHandler(request(user1, {
      coupleCode: code, tokenIndex: 3,
    }));
    assert.equal(result.won, true);
    assert.equal(result.rewardAwarded, true);
    const coupleAfterWin = (await db.doc(`couples/${code}`).get()).data();
    const gameAfterWin = (await db.doc(`couples/${code}/games/ludo`).get()).data();
    assert.equal(coupleAfterWin.coins, 90);
    assert.equal(gameAfterWin.rewardedTo, user1);
    assert.equal(gameAfterWin.rewardGranted, true);
    const gameLedger = await db.collection(`couples/${code}/economyLedger`)
      .where('gameId', '==', 'ludo').get();
    assert.equal(gameLedger.size, 1);
    assert.equal(gameLedger.docs[0].data().type, 'game_reward');

    await rejectsCode(
      () => handlers.moveLudoTokenHandler(request(user1, {
        coupleCode: code, tokenIndex: 3,
      })),
      'failed-precondition',
    );
    const coupleAfterRetry = (await db.doc(`couples/${code}`).get()).data();
    assert.equal(coupleAfterRetry.coins, 90);
  });

  it('rejects manipulated parameters and arbitrary catalog items', async () => {
    await seedGame({ phase: 'choose', dice: 6 });
    await rejectsCode(
      () => handlers.moveLudoTokenHandler(request(user1, {
        coupleCode: code, tokenIndex: 999,
      })),
      'invalid-argument',
    );
    await rejectsCode(
      () => handlers.purchaseItemHandler(request(user1, {
        coupleCode: code, itemId: 'give_me_999999_coins',
      })),
      'invalid-argument',
    );
  });

  it('rejects economy and game mutations after the couple is unlinked', async () => {
    await db.doc(`couples/${code}`).update({ status: 'unlinked' });
    await rejectsCode(
      () => handlers.performCoupleActionHandler(request(user1, {
        coupleCode: code, actionId: 'world_water',
      })),
      'failed-precondition',
    );
    await rejectsCode(
      () => handlers.purchaseItemHandler(request(user1, {
        coupleCode: code, itemId: 'house_basic',
      })),
      'failed-precondition',
    );
    await rejectsCode(
      () => handlers.claimDailyRewardHandler(request(user1, { coupleCode: code })),
      'failed-precondition',
    );
    await rejectsCode(
      () => handlers.joinLudoHandler(request(user1, { coupleCode: code })),
      'failed-precondition',
    );
  });

  it('purchases atomically, records an immutable receipt and makes retries idempotent', async () => {
    await db.doc(`couples/${code}`).update({ coins: 100 });
    const first = await handlers.purchaseItemHandler(request(user1, {
      coupleCode: code, itemId: 'flower_pot_pink',
    }));
    assert.equal(first.purchased, true);
    assert.equal(first.priceCharged, 30);
    assert.equal(first.balanceAfter, 70);
    assert.equal(first.receiptId, 'purchase_flower_pot_pink');

    const receipt = (await db.doc(
      `couples/${code}/economyLedger/${first.receiptId}`,
    ).get()).data();
    assert.equal(receipt.type, 'purchase');
    assert.equal(receipt.deltaCoins, -30);
    assert.equal(receipt.balanceAfter, 70);

    const retry = await handlers.purchaseItemHandler(request(user2, {
      coupleCode: code, itemId: 'flower_pot_pink',
    }));
    assert.equal(retry.purchased, false);
    assert.equal(retry.alreadyOwned, true);
    assert.equal(retry.priceCharged, 30);
    assert.equal(retry.balanceAfter, 70);
    const couple = (await db.doc(`couples/${code}`).get()).data();
    assert.equal(couple.coins, 70);
    assert.deepEqual(couple.ownedGardenItems, ['flower_pot_pink']);
  });

  it('rejects insufficient funds without a partial inventory or receipt', async () => {
    await rejectsCode(
      () => handlers.purchaseItemHandler(request(user1, {
        coupleCode: code, itemId: 'flower_pot_pink',
      })),
      'failed-precondition',
    );
    const couple = (await db.doc(`couples/${code}`).get()).data();
    assert.equal(couple.coins, 10);
    assert.equal(couple.ownedGardenItems, undefined);
    assert.equal((await db.doc(
      `couples/${code}/economyLedger/purchase_flower_pot_pink`,
    ).get()).exists, false);
  });

  it('charges only once when both members buy the same item concurrently', async () => {
    await db.doc(`couples/${code}`).update({ coins: 100 });
    const results = await Promise.all([
      handlers.purchaseItemHandler(request(user1, {
        coupleCode: code, itemId: 'flower_pot_pink',
      })),
      handlers.purchaseItemHandler(request(user2, {
        coupleCode: code, itemId: 'flower_pot_pink',
      })),
    ]);
    assert.equal(results.filter((result) => result.purchased).length, 1);
    assert.equal(results.filter((result) => result.alreadyOwned).length, 1);
    assert.equal((await db.doc(`couples/${code}`).get()).data().coins, 70);
    assert.equal((await db.collection(`couples/${code}/economyLedger`).get()).size, 1);
  });

  it('records action and daily-reward ledger entries in their balance transactions', async () => {
    await db.doc(`couples/${code}`).update({ coins: 0 });
    const action = await handlers.performCoupleActionHandler(request(user1, {
      coupleCode: code, actionId: 'world_water',
    }));
    assert.equal(action.awarded, true);
    assert.equal(action.coins, 25);
    assert.equal(action.balanceAfter, 25);
    assert.equal(action.plantStage, 1);
    assert.equal(action.plantWaterings, 1);
    const actionReceipt = (await db.doc(
      `couples/${code}/economyLedger/${action.receiptId}`,
    ).get()).data();
    assert.equal(actionReceipt.type, 'action');
    assert.equal(actionReceipt.deltaCoins, 25);
    const plant = (await db.doc(`couples/${code}`).get()).data().gardenPlant;
    assert.equal(plant.stage, 1);
    assert.equal(plant.waterings, 1);

    const daily = await handlers.claimDailyRewardHandler(request(user2, {
      coupleCode: code,
    }));
    assert.equal(daily.awarded, true);
    assert.equal(daily.balanceAfter, 55);
    const dailyReceipt = (await db.doc(
      `couples/${code}/economyLedger/${daily.receiptId}`,
    ).get()).data();
    assert.equal(dailyReceipt.type, 'daily_reward');
    assert.equal(dailyReceipt.deltaCoins, 30);
    assert.equal((await db.doc(`couples/${code}`).get()).data().coins, 55);
  });

  it('canonicalizes owned layouts, preserves starters and rejects stale revisions', async () => {
    await db.doc(`couples/${code}`).update({
      ownedGardenItems: ['flower_pot_pink'],
    });
    const result = await handlers.saveSharedLayoutHandler(request(user1, {
      coupleCode: code,
      area: 'garden',
      expectedRevision: 0,
      layout: [
        {
          id: 'tree_big_love_01', type: 'forged', asset: 'evil.png',
          x: 455, y: 340, width: 9999, height: 9999,
        },
        {
          id: 'pot_1700000000000', catalogItemId: 'flower_pot_pink',
          type: 'forged', asset: 'evil.png', x: 900, y: 650,
          width: 9999, height: 9999,
        },
      ],
    }));
    assert.equal(result.revision, 1);
    assert.equal(result.layout[0].asset, 'garden/tree_big_love.png');
    assert.equal(result.layout[0].width, 330);
    assert.equal(result.layout[1].asset, 'garden/flower_pot_pink.png');
    assert.equal(result.layout[1].type, 'pot');
    assert.equal(result.layout[1].width, 105);
    const couple = (await db.doc(`couples/${code}`).get()).data();
    assert.equal(couple.gardenRevision, 1);
    assert.deepEqual(couple.gardenLayout, result.layout);

    await rejectsCode(
      () => handlers.saveSharedLayoutHandler(request(user2, {
        coupleCode: code, area: 'garden', layout: [], expectedRevision: 0,
      })),
      'aborted',
    );
  });

  it('rejects manipulated coordinates, duplicate placements and unowned objects', async () => {
    await db.doc(`couples/${code}`).update({
      ownedGardenItems: ['flower_pot_pink'],
    });
    await rejectsCode(
      () => handlers.saveSharedLayoutHandler(request(user1, {
        coupleCode: code,
        area: 'garden',
        expectedRevision: 0,
        layout: [{
          id: 'pot_outside', catalogItemId: 'flower_pot_pink', x: 9999, y: 650,
        }],
      })),
      'invalid-argument',
    );
    await rejectsCode(
      () => handlers.saveSharedLayoutHandler(request(user1, {
        coupleCode: code,
        area: 'garden',
        expectedRevision: 0,
        layout: [
          { id: 'pot_one', catalogItemId: 'flower_pot_pink', x: 800, y: 650 },
          { id: 'pot_two', catalogItemId: 'flower_pot_pink', x: 1000, y: 650 },
        ],
      })),
      'failed-precondition',
    );
    await rejectsCode(
      () => handlers.saveSharedLayoutHandler(request(user1, {
        coupleCode: code,
        area: 'garden',
        expectedRevision: 0,
        layout: [{
          id: 'table_unowned', catalogItemId: 'table_garden', x: 900, y: 650,
        }],
      })),
      'failed-precondition',
    );
    assert.equal((await db.doc(`couples/${code}`).get()).data().gardenRevision, undefined);
  });

  it('rejects overlapping purchased objects while preserving starter compatibility', async () => {
    await db.doc(`couples/${code}`).update({
      ownedGardenItems: ['flower_pot_pink', 'table_garden'],
    });
    await rejectsCode(
      () => handlers.saveSharedLayoutHandler(request(user1, {
        coupleCode: code,
        area: 'garden',
        expectedRevision: 0,
        layout: [
          { id: 'pot_owned', catalogItemId: 'flower_pot_pink', x: 900, y: 650 },
          { id: 'table_owned', catalogItemId: 'table_garden', x: 900, y: 650 },
        ],
      })),
      'failed-precondition',
    );

    const starter = await handlers.saveSharedLayoutHandler(request(user1, {
      coupleCode: code,
      area: 'interior',
      expectedRevision: 0,
      layout: [
        { id: 'bed_01', x: 420, y: 650 },
        { id: 'tv_01', x: 370, y: 575 },
      ],
    }));
    assert.equal(starter.saved, true);
    assert.equal(starter.layout.length, 2);
  });

  it('equips free or owned houses but rejects an unowned house', async () => {
    await rejectsCode(
      () => handlers.equipHouseHandler(request(user1, {
        coupleCode: code, houseId: 'house_romantic',
      })),
      'failed-precondition',
    );
    const free = await handlers.equipHouseHandler(request(user1, {
      coupleCode: code, houseId: 'house_basic',
    }));
    assert.equal(free.equipped, true);
    await db.doc(`couples/${code}`).update({
      ownedGardenItems: ['house_romantic'],
    });
    const owned = await handlers.equipHouseHandler(request(user2, {
      coupleCode: code, houseId: 'house_romantic',
    }));
    assert.equal(owned.equipped, true);
    assert.equal(
      (await db.doc(`couples/${code}`).get()).data().selectedHouseId,
      'house_romantic',
    );
  });

  it('keeps couple-question answers private until both players respond', async () => {
    await handlers.openMiniGameHandler(request(user1, {
      coupleCode: code, gameId: 'couple_questions',
    }));
    await handlers.openMiniGameHandler(request(user2, {
      coupleCode: code, gameId: 'couple_questions',
    }));

    await handlers.playMiniGameHandler(request(user1, {
      coupleCode: code,
      gameId: 'couple_questions',
      action: 'answer',
      payload: { text: 'Un recuerdo secreto' },
    }));

    let publicGame = (await db.doc(`couples/${code}/games/couple_questions`).get()).data();
    let privateGame = (await db.doc(`privateGameState/${code}__couple_questions`).get()).data();
    assert.deepEqual(publicGame.answers, {});
    assert.equal(privateGame.answers[user1], 'Un recuerdo secreto');

    const result = await handlers.playMiniGameHandler(request(user2, {
      coupleCode: code,
      gameId: 'couple_questions',
      action: 'answer',
      payload: { text: 'Otro recuerdo secreto' },
    }));
    assert.equal(result.complete, true);
    assert.equal(result.rewardAwarded, true);
    publicGame = (await db.doc(`couples/${code}/games/couple_questions`).get()).data();
    assert.equal(publicGame.answers[user1], 'Un recuerdo secreto');
    assert.equal(publicGame.answers[user2], 'Otro recuerdo secreto');
    assert.equal((await db.doc(`couples/${code}`).get()).data().coins, 20);
  });

  it('creates memory cards privately and rejects outsiders', async () => {
    await rejectsCode(
      () => handlers.openMiniGameHandler(request(outsider, {
        coupleCode: code, gameId: 'couple_memory',
      })),
      'permission-denied',
    );
    await handlers.openMiniGameHandler(request(user1, {
      coupleCode: code, gameId: 'couple_memory',
    }));
    const publicGame = (await db.doc(`couples/${code}/games/couple_memory`).get()).data();
    const privateGame = (await db.doc(`privateGameState/${code}__couple_memory`).get()).data();
    assert.equal(publicGame.cards.every((card) => card === ''), true);
    assert.equal(privateGame.deck.length, 16);
    assert.equal(new Set(privateGame.deck).size, 8);
  });

  it('validates tic-tac-toe turns and rewards the server-detected winner once', async () => {
    await handlers.openMiniGameHandler(request(user1, {
      coupleCode: code, gameId: 'tic_tac_toe',
    }));
    await handlers.openMiniGameHandler(request(user2, {
      coupleCode: code, gameId: 'tic_tac_toe',
    }));
    const move = (uid, index) => handlers.playMiniGameHandler(request(uid, {
      coupleCode: code,
      gameId: 'tic_tac_toe',
      action: 'move',
      payload: { index },
    }));
    await move(user1, 0);
    await rejectsCode(() => move(user1, 1), 'failed-precondition');
    await move(user2, 3);
    await move(user1, 1);
    await move(user2, 4);
    const result = await move(user1, 2);
    assert.equal(result.winnerUid, user1);
    assert.equal(result.rewardAwarded, true);
    assert.equal((await db.doc(`couples/${code}`).get()).data().coins, 30);
    await rejectsCode(() => move(user2, 8), 'failed-precondition');
  });

  it('does not reveal rock-paper-scissors choices before both submit', async () => {
    await handlers.openMiniGameHandler(request(user1, {
      coupleCode: code, gameId: 'rock_paper_scissors',
    }));
    await handlers.openMiniGameHandler(request(user2, {
      coupleCode: code, gameId: 'rock_paper_scissors',
    }));
    const choose = (uid, choice) => handlers.playMiniGameHandler(request(uid, {
      coupleCode: code,
      gameId: 'rock_paper_scissors',
      action: 'choose',
      payload: { choice },
    }));
    await choose(user1, 'rock');
    let game = (await db.doc(`couples/${code}/games/rock_paper_scissors`).get()).data();
    assert.deepEqual(game.choices, {});
    const result = await choose(user2, 'paper');
    assert.equal(result.winnerUid, user2);
    game = (await db.doc(`couples/${code}/games/rock_paper_scissors`).get()).data();
    assert.equal(game.choices[user1], 'rock');
    assert.equal(game.choices[user2], 'paper');
  });

  it('requires both challenge confirmations and awards only once per day', async () => {
    await handlers.openMiniGameHandler(request(user1, {
      coupleCode: code, gameId: 'challenge_roulette',
    }));
    await handlers.openMiniGameHandler(request(user2, {
      coupleCode: code, gameId: 'challenge_roulette',
    }));
    const confirm = (uid) => handlers.playMiniGameHandler(request(uid, {
      coupleCode: code,
      gameId: 'challenge_roulette',
      action: 'confirm',
      payload: {},
    }));
    assert.equal((await confirm(user1)).complete, false);
    const result = await confirm(user2);
    assert.equal(result.complete, true);
    assert.equal(result.rewardAwarded, true);
    assert.equal((await db.doc(`couples/${code}`).get()).data().coins, 18);

    await handlers.playMiniGameHandler(request(user1, {
      coupleCode: code, gameId: 'challenge_roulette', action: 'next', payload: {},
    }));
    await handlers.playMiniGameHandler(request(user2, {
      coupleCode: code, gameId: 'challenge_roulette', action: 'next', payload: {},
    }));
    await confirm(user1);
    const second = await confirm(user2);
    assert.equal(second.rewardAwarded, false);
    assert.equal((await db.doc(`couples/${code}`).get()).data().coins, 18);
  });

  it('keeps movie answers private and validates normalized guesses on the server', async () => {
    await handlers.openMiniGameHandler(request(user1, {
      coupleCode: code, gameId: 'movie_guess',
    }));
    await handlers.openMiniGameHandler(request(user2, {
      coupleCode: code, gameId: 'movie_guess',
    }));
    const publicBefore = (await db.doc(`couples/${code}/games/movie_guess`).get()).data();
    const privateGame = (await db.doc(`privateGameState/${code}__movie_guess`).get()).data();
    assert.equal(Object.hasOwn(publicBefore, 'answer'), false);

    const wrong = await handlers.playMiniGameHandler(request(user1, {
      coupleCode: code, gameId: 'movie_guess', action: 'guess', payload: { guess: 'No es esta' },
    }));
    assert.equal(wrong.correct, false);
    const correct = await handlers.playMiniGameHandler(request(user2, {
      coupleCode: code,
      gameId: 'movie_guess',
      action: 'guess',
      payload: { guess: privateGame.answer.toUpperCase() },
    }));
    assert.equal(correct.correct, true);
    assert.equal(correct.rewardAwarded, true);
    const publicAfter = (await db.doc(`couples/${code}/games/movie_guess`).get()).data();
    assert.equal(publicAfter.answer, privateGame.answer);
  });
});

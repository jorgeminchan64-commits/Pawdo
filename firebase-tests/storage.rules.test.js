'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc } = require('firebase/firestore');
const { ref, uploadBytes, getBytes, deleteObject } = require('firebase/storage');

const projectId = 'pawdo-aeda8';
const coupleCode = 'ABC123';
const otherCoupleCode = 'XYZ789';
const pendingCoupleCode = 'WAIT24';
const user1 = 'user-one';
const user2 = 'user-two';
const outsider = 'outsider';
const smallJpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xdb]);
let testEnv;

function storage(uid) {
  return uid ? testEnv.authenticatedContext(uid).storage() : testEnv.unauthenticatedContext().storage();
}

function photoRef(uid, name = 'photo.jpg', code = coupleCode) {
  return ref(storage(uid), `couples/${code}/photos/${name}`);
}

function chatMetadata(uid, contentType = 'image/jpeg', code = coupleCode) {
  return {
    contentType,
    customMetadata: { uploadedBy: uid || 'anonymous', coupleCode: code },
  };
}

function audioRef(uid, name = '1234567890_voice.m4a', code = coupleCode) {
  return ref(storage(uid), `couples/${code}/audio/${name}`);
}

function audioMetadata(uid, durationMs = '1500', code = coupleCode) {
  return {
    contentType: 'audio/mp4',
    customMetadata: { uploadedBy: uid || 'anonymous', coupleCode: code, durationMs },
  };
}

function memoryRef(uid, memoryId, fileName, code = coupleCode) {
  return ref(storage(uid), `couples/${code}/memories/${memoryId}/${fileName}`);
}

function memoryMetadata(uid, memoryId, variant, code = coupleCode) {
  return {
    contentType: 'image/jpeg',
    customMetadata: {
      uploadedBy: uid, coupleCode: code, memoryId, variant,
    },
  };
}

describe('Pawdo Storage Rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
      storage: { rules: fs.readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8') },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.clearStorage();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'couples', coupleCode), { user1, user2, coins: 0 });
      await setDoc(doc(adminDb, 'couples', otherCoupleCode), {
        user1: 'other-one', user2: 'other-two', coins: 0,
      });
      await setDoc(doc(adminDb, 'couples', pendingCoupleCode), {
        user1, user2: null, createdBy: user1, status: 'pending',
      });
      await setDoc(doc(adminDb, 'users', user1), { uid: user1, coupleCode });
      await setDoc(doc(adminDb, 'users', user2), { uid: user2, coupleCode });
      await setDoc(doc(adminDb, 'users', outsider), { uid: outsider });
    });
  });

  after(async () => {
    if (testEnv) await testEnv.cleanup();
  });

  it('allows user1 to upload a JPEG <= 1 MB', async () => {
    await assertSucceeds(uploadBytes(photoRef(user1, '1234567890_photo.jpg'), smallJpeg, chatMetadata(user1)));
  });

  it('allows user2 to upload a valid JPEG with ownership metadata', async () => {
    await assertSucceeds(uploadBytes(photoRef(user2, '1234567890_partner.jpg'), smallJpeg, chatMetadata(user2)));
  });

  it('allows both members to read', async () => {
    await uploadBytes(photoRef(user1, '1234567890_read.jpg'), smallJpeg, chatMetadata(user1));
    await assertSucceeds(getBytes(photoRef(user1, '1234567890_read.jpg')));
    await assertSucceeds(getBytes(photoRef(user2, '1234567890_read.jpg')));
  });

  it('revokes shared photo access after unlinking', async () => {
    await uploadBytes(photoRef(user1, '1234567890_archived.jpg'), smallJpeg, chatMetadata(user1));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'couples', coupleCode), { status: 'unlinked' });
    });
    await assertFails(getBytes(photoRef(user1, '1234567890_archived.jpg')));
    await assertFails(getBytes(photoRef(user2, '1234567890_archived.jpg')));
  });

  it('denies an outsider read and upload', async () => {
    await uploadBytes(photoRef(user1, '1234567890_outsider.jpg'), smallJpeg, chatMetadata(user1));
    await assertFails(getBytes(photoRef(outsider, '1234567890_outsider.jpg')));
    await assertFails(uploadBytes(photoRef(outsider, '1234567890_bad.jpg'), smallJpeg, chatMetadata(outsider)));
  });

  it('denies unauthenticated read and upload', async () => {
    await uploadBytes(photoRef(user1, '1234567890_anonymous.jpg'), smallJpeg, chatMetadata(user1));
    await assertFails(getBytes(photoRef(null, '1234567890_anonymous.jpg')));
    await assertFails(uploadBytes(photoRef(null, '1234567890_bad.jpg'), smallJpeg, chatMetadata(null)));
  });

  it('denies files larger than 1 MB', async () => {
    const oversized = new Uint8Array(1024 * 1024 + 1);
    await assertFails(uploadBytes(photoRef(user1, '1234567890_large.jpg'), oversized, chatMetadata(user1)));
  });

  for (const [label, contentType] of [['PDF', 'application/pdf'], ['video', 'video/mp4']]) {
    it(`denies ${label}`, async () => {
      await assertFails(uploadBytes(photoRef(user1, `1234567890_bad-${label}.jpg`), smallJpeg, chatMetadata(user1, contentType)));
    });
  }

  it('denies access through another couple path', async () => {
    await assertFails(uploadBytes(photoRef(user1, '1234567890_bad.jpg', otherCoupleCode), smallJpeg, chatMetadata(user1, 'image/jpeg', otherCoupleCode)));
  });

  it('denies photo access before the couple is complete', async () => {
    await assertFails(uploadBytes(
      photoRef(user1, '1234567890_pending.jpg', pendingCoupleCode),
      smallJpeg,
      chatMetadata(user1, 'image/jpeg', pendingCoupleCode),
    ));
  });

  it('denies overwriting an existing file', async () => {
    await uploadBytes(photoRef(user1, '1234567890_overwrite.jpg'), smallJpeg, chatMetadata(user1));
    await assertFails(uploadBytes(photoRef(user1, '1234567890_overwrite.jpg'), smallJpeg, chatMetadata(user1)));
  });

  it('keeps shared photo deletion server-only', async () => {
    await uploadBytes(photoRef(user1, '1234567890_delete.jpg'), smallJpeg, chatMetadata(user1));
    await assertFails(deleteObject(photoRef(outsider, '1234567890_delete.jpg')));
    await assertFails(deleteObject(photoRef(user1, '1234567890_delete.jpg')));
    await assertFails(deleteObject(photoRef(user2, '1234567890_delete.jpg')));
  });

  it('allows bounded M4A voice notes and member playback', async () => {
    const bytes = new Uint8Array([0, 0, 0, 20, 102, 116, 121, 112]);
    await assertSucceeds(uploadBytes(audioRef(user1), bytes, audioMetadata(user1)));
    await assertSucceeds(getBytes(audioRef(user1)));
    await assertSucceeds(getBytes(audioRef(user2)));
  });

  it('rejects forged or unsupported voice-note uploads', async () => {
    const bytes = new Uint8Array([1, 2, 3, 4]);
    await assertFails(uploadBytes(
      audioRef(outsider, '1234567890_outsider.m4a'), bytes, audioMetadata(outsider),
    ));
    await assertFails(uploadBytes(
      audioRef(user1, '1234567890_wrong.m4a'), bytes,
      { ...audioMetadata(user1), contentType: 'audio/mpeg' },
    ));
    await assertFails(uploadBytes(
      audioRef(user1, '1234567890_duration.m4a'), bytes, audioMetadata(user1, '999999'),
    ));
    await assertFails(uploadBytes(
      audioRef(user1, '1234567890_wrong.txt'), bytes, audioMetadata(user1),
    ));
  });

  it('keeps voice-note deletion server-only and revokes access after unlinking', async () => {
    const target = audioRef(user1, '1234567890_private.m4a');
    await uploadBytes(target, new Uint8Array([1, 2, 3]), audioMetadata(user1));
    await assertFails(deleteObject(target));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'couples', coupleCode), { status: 'unlinked' });
    });
    await assertFails(getBytes(audioRef(user1, '1234567890_private.m4a')));
    await assertFails(getBytes(audioRef(user2, '1234567890_private.m4a')));
  });

  it('allows optimized album originals and thumbnails for both members', async () => {
    const memoryId = 'memory123456';
    await assertSucceeds(uploadBytes(
      memoryRef(user1, memoryId, 'original.jpg'), smallJpeg,
      memoryMetadata(user1, memoryId, 'original'),
    ));
    await assertSucceeds(uploadBytes(
      memoryRef(user1, memoryId, 'thumb.jpg'), smallJpeg,
      memoryMetadata(user1, memoryId, 'thumbnail'),
    ));
    await assertSucceeds(getBytes(memoryRef(user2, memoryId, 'original.jpg')));
    await assertSucceeds(getBytes(memoryRef(user2, memoryId, 'thumb.jpg')));
  });

  it('rejects forged album paths, variants and oversized thumbnails', async () => {
    const memoryId = 'memory123456';
    await assertFails(uploadBytes(
      memoryRef(outsider, memoryId, 'original.jpg'), smallJpeg,
      memoryMetadata(outsider, memoryId, 'original'),
    ));
    await assertFails(uploadBytes(
      memoryRef(user1, memoryId, 'thumb.jpg'), smallJpeg,
      memoryMetadata(user1, memoryId, 'original'),
    ));
    await assertFails(uploadBytes(
      memoryRef(user1, memoryId, 'other.jpg'), smallJpeg,
      memoryMetadata(user1, memoryId, 'original'),
    ));
    await assertFails(uploadBytes(
      memoryRef(user1, memoryId, 'thumb.jpg'), new Uint8Array(250 * 1024 + 1),
      memoryMetadata(user1, memoryId, 'thumbnail'),
    ));
  });

  it('allows a profile photo only to its owner and active partner', async () => {
    const ownerRef = ref(storage(user1), `profile_photos/${user1}.jpg`);
    const partnerRef = ref(storage(user2), `profile_photos/${user1}.jpg`);
    const outsiderRef = ref(storage(outsider), `profile_photos/${user1}.jpg`);
    await assertSucceeds(
      uploadBytes(ownerRef, smallJpeg, { contentType: 'image/jpeg' }),
    );
    await assertSucceeds(getBytes(ownerRef));
    await assertSucceeds(getBytes(partnerRef));
    await assertFails(getBytes(outsiderRef));
  });
});

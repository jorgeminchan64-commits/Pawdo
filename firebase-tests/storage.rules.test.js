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

// firebase emulators:exec --only firestore --project demo-nostargia "npm --prefix tools/rules-test test"
import { after, before, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nostargia',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

beforeEach(() => env.clearFirestore());
after(() => env.cleanup());

test('本人はプロフィールと星とタグを読み書き・削除できる', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/alice'), { userName: 'アリス' }));
  await assertSucceeds(getDoc(doc(db, 'users/alice')));
  await assertSucceeds(setDoc(doc(db, 'users/alice/stars/s1'), { scale: 2 }));
  await assertSucceeds(getDoc(doc(db, 'users/alice/stars/s1')));
  await assertSucceeds(setDoc(doc(db, 'users/alice/tags/t1'), { name: '休日' }));
  await assertSucceeds(deleteDoc(doc(db, 'users/alice/stars/s1')));
  await assertSucceeds(deleteDoc(doc(db, 'users/alice')));
});

test('他人のデータは読み書きできない', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice/stars/s1'), { scale: 2 });
  });
  const bob = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(bob, 'users/alice')));
  await assertFails(getDoc(doc(bob, 'users/alice/stars/s1')));
  await assertFails(setDoc(doc(bob, 'users/alice/stars/s2'), { scale: 2 }));
  await assertFails(deleteDoc(doc(bob, 'users/alice/stars/s1')));
});

test('未ログインでは何もできない', async () => {
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'users/alice')));
  await assertFails(setDoc(doc(anon, 'users/alice'), { userName: 'x' }));
});

test('users 以外の場所には書けない', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'public/x'), { a: 1 }));
  await assertFails(setDoc(doc(db, 'alice/x'), { a: 1 }));
});

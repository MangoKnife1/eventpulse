/**
 * Shows how an account is set up and marks its email as verified.
 *
 *   node verify-user.js you@gmail.com
 *   (or)  npm run verify -- you@gmail.com
 *
 * Use it for accounts created BEFORE email verification was added to the app:
 * those can't sign in with a password until their email is verified.
 * Needs tools/seed/serviceAccountKey.json (same file the seeder uses).
 */
const fs = require('fs');
const path = require('path');

const email = (process.argv[2] || '').trim();
const keyPath = path.join(__dirname, 'serviceAccountKey.json');

function fail(msg) {
  console.error(`\n✖ ${msg}\n`);
  process.exit(1);
}

if (!email) fail('Usage: node verify-user.js you@gmail.com');
if (!fs.existsSync(keyPath)) fail('Missing tools/seed/serviceAccountKey.json');

const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({ credential: cert(require(keyPath)) });

(async () => {
  let user;
  try {
    user = await getAuth().getUserByEmail(email);
  } catch {
    fail(`No account found for ${email}. Check the spelling, or register it in the app.`);
  }

  const providers = user.providerData.map((p) => p.providerId);
  const profile = (await getFirestore().collection('users').doc(user.uid).get()).data();

  console.log(`\nAccount:        ${user.email}`);
  console.log(`Sign-in types:  ${providers.join(', ') || '(none)'}`);
  console.log(`Disabled:       ${user.disabled ? 'YES (enable it in Firebase console > Authentication)' : 'no'}`);
  console.log(`Email verified: ${user.emailVerified}`);
  console.log(`App role:       ${profile ? profile.role : '(no profile document yet: sign in once)'}\n`);

  if (user.disabled) fail('This account is disabled, so it cannot sign in.');

  if (!user.emailVerified) {
    await getAuth().updateUser(user.uid, { emailVerified: true });
    console.log('✓ Email marked as verified. You can sign in now.');
  } else {
    console.log('Email was already verified.');
  }

  if (!providers.includes('password') && providers.includes('google.com')) {
    console.log('Note: this account has no password. Use "Continue with Google" to sign in.');
  }
})().catch((err) => fail(err.message || String(err)));

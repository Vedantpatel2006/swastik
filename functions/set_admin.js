/**
 * One-time script to set admin custom claim for vedantchhatrola@gmail.com
 * Run with: node set_admin.js
 * Delete this file after running.
 */

const admin = require('firebase-admin');

// Initialize with application default credentials
// Make sure you've run: firebase login  (or set GOOGLE_APPLICATION_CREDENTIALS)
admin.initializeApp({
  projectId: 'intership-96534',
});

async function setAdminClaim() {
  const email = 'vedantchhatrola@gmail.com';
  const uid = 'yh9vdnjXdmNyRxwyy8cdyoe47Rh1';

  try {
    // Set the custom claim
    await admin.auth().setCustomUserClaims(uid, { admin: true, role: 'admin' });
    console.log(`✅ Custom claim set: admin=true for ${email} (${uid})`);

    // Verify it was set
    const user = await admin.auth().getUser(uid);
    console.log('✅ Verified custom claims:', user.customClaims);

    console.log('\n🎉 Done! Now sign out and sign back in to the app.');
    console.log('   The new token with admin claim will be issued on next login.');
  } catch (error) {
    console.error('❌ Error:', error.message);
  }

  process.exit(0);
}

setAdminClaim();

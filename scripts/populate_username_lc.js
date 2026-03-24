// scripts/populate_username_lc.js
// Usage: node populate_username_lc.js /path/to/serviceAccountKey.json [--dry-run] [--limit=N]
//
// Options:
//   --dry-run    : don't write changes, only print what would be updated
//   --limit=N    : only process up to N updates (useful for testing)

const admin = require('firebase-admin');
const fs = require('fs');

async function main() {
  const args = process.argv.slice(2);
  const saPath = args.find(a => !a.startsWith('--'));
  const dryRun = args.includes('--dry-run');
  const limitArg = args.find(a => a.startsWith('--limit='));
  const limit = limitArg ? parseInt(limitArg.split('=')[1], 10) : null;

  if (!saPath) {
    console.error('Usage: node populate_username_lc.js /path/to/serviceAccountKey.json [--dry-run] [--limit=N]');
    process.exit(1);
  }

  if (!fs.existsSync(saPath)) {
    console.error('Service account file not found:', saPath);
    process.exit(1);
  }

  const serviceAccount = require(saPath);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  console.log('Scanning users collection...');
  const usersSnap = await db.collection('users').get();
  console.log('Found', usersSnap.size, 'users');

  let updated = 0;
  const batchSize = 500;
  let batch = db.batch();
  let countInBatch = 0;
  const toUpdateDocs = [];

  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const username = (data.username || '') + '';
    const username_lc = username.toLowerCase();
    if (data.username_lc !== username_lc) {
      toUpdateDocs.push({ ref: doc.ref, username_lc });
    }
  }

  console.log('Documents that need update:', toUpdateDocs.length);

  if (dryRun) {
    console.log('--dry-run enabled; no changes will be written. Showing up to 50 examples:');
    toUpdateDocs.slice(0, 50).forEach((d, i) => console.log(i + 1 + ')', d.ref.path, '->', d.username_lc));
    console.log('Dry-run complete. Total candidates:', toUpdateDocs.length);
    process.exit(0);
  }

  for (const d of toUpdateDocs) {
    batch.update(d.ref, { username_lc: d.username_lc });
    updated++;
    countInBatch++;

    if (limit && updated >= limit) {
      if (countInBatch > 0) {
        await batch.commit();
        console.log('Committed final partial batch; progress updated =', updated);
      }
      console.log('Limit reached (', limit, '). Stopping.');
      console.log('Done. Updated', updated, 'documents.');
      process.exit(0);
    }

    if (countInBatch >= batchSize) {
      await batch.commit();
      batch = db.batch();
      countInBatch = 0;
      console.log('Committed batch; progress updated =', updated);
    }
  }

  if (countInBatch > 0) {
    await batch.commit();
  }

  console.log('Done. Updated', updated, 'documents.');
  process.exit(0);
}

main().catch(err => { console.error(err); process.exit(2); });

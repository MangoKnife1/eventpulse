/**
 * EventPulse demo-data seeder.
 *
 *   npm install               (once)
 *   npm run seed              the 7 hand-written demo events
 *   npm run seed:random       the 7 + 20 random events
 *   node seed.js --random 35  the 7 + any number (max 40) of random events
 *   npm run reset             also put approvals, counters and tickets back to the start
 *   npm run wipe              delete ALL seeded events (ids starting "seed_") and their tickets
 *
 * What it does
 *   1. Uploads banners to YOUR Cloudinary (unsigned preset, no secret needed).
 *      Images come from tools/seed/images/ if you put files there, otherwise from online samples.
 *   2. Writes the events to YOUR Firestore, owned by ORGANIZER_EMAIL.
 *
 * Safe to re-run: events use fixed ids (seed_evt_XX / seed_rnd_XX), the random ones are
 * the same every time, banners already on Cloudinary are not uploaded again, and dates
 * are moved back to "upcoming".
 *
 * Needs (all local, never committed):
 *   - tools/seed/serviceAccountKey.json  (Firebase console > Project settings >
 *     Service accounts > Generate new private key)
 *   - tools/seed/.env                    (see .env.example)
 */
const fs = require('fs');
const path = require('path');

// ── tiny .env loader (so it works on any Node version / OS) ──────────────────
const envFile = path.join(__dirname, '.env');
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m && !line.trim().startsWith('#') && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  }
}

const CLOUD = process.env.CLOUDINARY_CLOUD_NAME;
const PRESET = process.env.CLOUDINARY_UPLOAD_PRESET;
const ORGANIZER_EMAIL = process.env.ORGANIZER_EMAIL;
const RESET = process.argv.includes('--reset');
const WIPE = process.argv.includes('--wipe');
const randIdx = process.argv.indexOf('--random');
const RANDOM_COUNT = randIdx === -1 ? 0 : Math.min(40, Math.max(0, parseInt(process.argv[randIdx + 1], 10) || 20));

function fail(msg) {
  console.error(`\n✖ ${msg}\n`);
  process.exit(1);
}

if (!WIPE && (!CLOUD || !PRESET)) fail('Set CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET in tools/seed/.env');
if (!WIPE && !ORGANIZER_EMAIL) fail('Set ORGANIZER_EMAIL in tools/seed/.env (an account that already exists in your app).');

const keyPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  fail('Missing tools/seed/serviceAccountKey.json (Firebase console > Project settings > Service accounts > Generate new private key).');
}

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

initializeApp({ credential: cert(require(keyPath)) });
const db = getFirestore();

// ── Demo events (edit freely) ────────────────────────────────────────────────
// daysFromNow / hour are used to build the date, so events are always upcoming.
// approved: false  => appears in the admin "Pending Proposals" list, for the approval demo.
const IMG = (id) => `https://images.unsplash.com/${id}?w=1200&auto=format&fit=crop&q=80`;

const EVENTS = [
  {
    n: 1, approved: true, category: 'Technology', daysFromNow: 3, hour: 14,
    title: 'Flutter & Firebase Workshop',
    description: 'Hands-on session building a real-time mobile app with Flutter and Firebase. Bring a laptop; starter code is provided.',
    venueName: 'IT Laboratory 2', location: 'Main Campus, Engineering Building',
    capacity: 60, price: 0, tags: ['Tech', 'Flutter', 'Firebase', 'Workshop'],
    image: IMG('photo-1540575467063-178a50c2df87'),
  },
  {
    n: 2, approved: true, category: 'Design', daysFromNow: 5, hour: 10,
    title: 'UI/UX Design Sprint',
    description: 'A one-day design sprint: research, sketch, prototype, and test a small app idea with your team.',
    venueName: 'Design Studio', location: 'Arts & Sciences Building, 2nd Floor',
    capacity: 40, price: 0, tags: ['Design', 'UX/UI', 'Figma', 'Teamwork'],
    image: IMG('photo-1531403009284-440f080d1e12'),
  },
  {
    n: 3, approved: true, category: 'Music & Arts', daysFromNow: 8, hour: 18,
    title: 'Acoustic Night: Open Mic',
    description: 'An evening of live acoustic performances by students and alumni. Sign up on the night to perform.',
    venueName: 'University Amphitheater', location: 'Central Campus Grounds',
    capacity: 150, price: 50, tags: ['Music', 'Social', 'Live'],
    image: IMG('photo-1511671782779-c97d3d27a1d4'),
  },
  {
    n: 4, approved: true, category: 'Community', daysFromNow: 10, hour: 7,
    title: 'Community Tree Planting Drive',
    description: 'Join the campus community in planting native trees. Tools, seedlings and refreshments are provided.',
    venueName: 'Campus Green Belt', location: 'East Campus Gate',
    capacity: 100, price: 0, tags: ['Community', 'Eco', 'Volunteering', 'Social'],
    image: IMG('photo-1542601906990-b4d3fb778b09'),
  },
  {
    n: 5, approved: true, category: 'Gaming', daysFromNow: 14, hour: 9,
    title: 'Game Jam: Build a Game in a Day',
    description: 'Form a team and build a small playable game in one day. Prizes for the best gameplay, art, and concept.',
    venueName: 'Innovation Pavilion', location: 'Technology Wing, Ground Floor',
    capacity: 50, price: 0, tags: ['Gaming', 'Tech', 'Networking', 'Competition'],
    image: IMG('photo-1511512578047-dfb367046420'),
  },
  // Pending: these are for demonstrating the admin approval step.
  {
    n: 6, approved: false, category: 'Technology', daysFromNow: 18, hour: 13,
    title: 'Intro to Cloud & Cybersecurity Basics',
    description: 'Beginner-friendly talk on cloud services and everyday cybersecurity habits, followed by a Q&A.',
    venueName: 'Seminar Hall A', location: 'Administration Building',
    capacity: 120, price: 0, tags: ['Tech', 'Security', 'Cloud'],
    image: IMG('photo-1517048676732-d65bc937f952'),
  },
  {
    n: 7, approved: false, category: 'Community', daysFromNow: 21, hour: 15,
    title: 'Student Org Fair & Networking Day',
    description: 'Meet campus organizations, learn how to join, and connect with student leaders.',
    venueName: 'Gymnasium', location: 'Sports Complex',
    capacity: 200, price: 0, tags: ['Community', 'Networking', 'Social'],
    image: IMG('photo-1523580494863-6f3031224c94'),
  },
];

// ── Random event generator (deterministic: same events on every run) ─────────
const POOLS = {
  Technology: {
    titles: ['Intro to Python for Beginners', 'Web Development Crash Course', 'Cybersecurity Awareness Talk', 'Mobile App Clinic', 'Data Science Meetup', 'Hack Night', 'Cloud Computing Basics', 'AI Tools for Students'],
    descriptions: ['Hands-on session with guided exercises. Bring a laptop; no experience needed.', 'Short talks, live demos, and time to ask the speakers your questions.', 'Learn by building. Work in small groups with mentors on hand.'],
    tags: ['Tech', 'Workshop', 'Networking'],
    images: ['photo-1540575467063-178a50c2df87', 'photo-1519389950473-47ba0277781c', 'photo-1517048676732-d65bc937f952'],
  },
  Design: {
    titles: ['Figma Basics Workshop', 'Poster Design Challenge', 'Branding 101', 'Photography Walk', 'Portfolio Review Night', 'Color & Typography Talk', 'Sketching Social', 'Motion Design Intro'],
    descriptions: ['A relaxed creative session. Materials are provided; just bring ideas.', 'Get friendly, practical feedback from peers and invited designers.', 'Learn the fundamentals, then apply them in a short group activity.'],
    tags: ['Design', 'Creative', 'Workshop'],
    images: ['photo-1531403009284-440f080d1e12', 'photo-1561070791-2526d30994b5', 'photo-1558655146-9f40138edfeb'],
  },
  'Music & Arts': {
    titles: ['Acoustic Jam Session', 'Battle of the Bands', 'Spoken Word Evening', 'Open Mic Night', 'Art Exhibit Opening', 'Choir Showcase', 'Film Screening & Discussion', 'Street Dance Showcase'],
    descriptions: ['An evening of student talent. Come to watch or sign up to perform.', 'Live performances, good company, and light refreshments.', 'Celebrate local creativity with performances and exhibits.'],
    tags: ['Music', 'Live', 'Social'],
    images: ['photo-1511671782779-c97d3d27a1d4', 'photo-1493225457124-a3eb161ffa5f', 'photo-1514320291840-2e0a9bf2a9ae'],
  },
  Community: {
    titles: ['Community Clean-Up Drive', 'Blood Donation Day', 'Book Swap & Reading Circle', 'Outreach Program Volunteer Day', 'Campus Fun Run', 'Leadership Forum', 'Alumni Homecoming Mixer', 'Wellness & Mental Health Fair'],
    descriptions: ['Join your fellow students and make a difference. Everyone is welcome.', 'A friendly gathering to meet new people and give back.', 'Bring a friend! Snacks and materials are provided.'],
    tags: ['Community', 'Volunteering', 'Social'],
    images: ['photo-1542601906990-b4d3fb778b09', 'photo-1559027615-cd4628902d4a', 'photo-1523580494863-6f3031224c94'],
  },
  Gaming: {
    titles: ['Mobile Legends Tournament', 'Chess Open', 'Board Game Night', 'Valorant Scrim Day', 'Retro Arcade Meetup', 'Game Dev Show & Tell', 'FIFA Friendly Cup', 'Esports Watch Party'],
    descriptions: ['Friendly competition with prizes for the top teams. Sign up solo or with friends.', 'Casual games, snacks, and good company. All skill levels welcome.', 'Show off your skills or just come to cheer.'],
    tags: ['Gaming', 'Competition', 'Social'],
    images: ['photo-1511512578047-dfb367046420', 'photo-1542751371-adc38448a05e', 'photo-1550745165-9bc0b252726f'],
  },
};
const VENUES = [
  ['Seminar Hall A', 'Administration Building'], ['IT Laboratory 1', 'Engineering Building'],
  ['University Amphitheater', 'Central Campus Grounds'], ['Gymnasium', 'Sports Complex'],
  ['Innovation Pavilion', 'Technology Wing, Ground Floor'], ['Library Function Room', 'Library, 3rd Floor'],
  ['Design Studio', 'Arts & Sciences Building'], ['Campus Green Belt', 'East Campus Gate'],
];
const CAPACITIES = [30, 40, 60, 80, 100, 150, 200];
const PRICES = [0, 0, 0, 0, 0, 50, 100];
const HOURS = [8, 9, 10, 13, 14, 15, 16, 18];

function mulberry32(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function buildRandomEvents(count) {
  const rng = mulberry32(20260930);
  const pick = (arr) => arr[Math.floor(rng() * arr.length)];
  const cats = Object.keys(POOLS);
  const used = new Map();
  const out = [];
  for (let i = 0; i < count; i++) {
    const category = cats[i % cats.length];
    const pool = POOLS[category];
    const k = used.get(category) || 0;
    used.set(category, k + 1);
    const [venueName, location] = pick(VENUES);
    out.push({
      id: `seed_rnd_${pad(i + 1)}`,
      code: `EP-EVT-RND${pad(i + 1)}`,
      approved: rng() > 0.12, // roughly 1 in 8 is left pending
      category,
      daysFromNow: 1 + Math.floor(rng() * 45),
      hour: pick(HOURS),
      title: pool.titles[k % pool.titles.length] + (k >= pool.titles.length ? ' Vol. 2' : ''),
      description: pick(pool.descriptions),
      venueName, location,
      capacity: pick(CAPACITIES),
      price: pick(PRICES),
      tags: pool.tags,
      image: IMG(pick(pool.images)),
      category_slug: slug(category),
    });
  }
  return out;
}

const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

// ── Local images (optional) ──────────────────────────────────────────────────
const IMAGES_DIR = path.join(__dirname, 'images');
function localImages(categorySlug) {
  const list = (dir) =>
    fs.existsSync(dir)
      ? fs.readdirSync(dir).filter((f) => /\.(jpe?g|png|webp)$/i.test(f)).map((f) => path.join(dir, f))
      : [];
  const specific = categorySlug ? list(path.join(IMAGES_DIR, categorySlug)) : [];
  return specific.length ? specific : list(IMAGES_DIR);
}

// ── Helpers ──────────────────────────────────────────────────────────────────
// source = remote URL string, or { file: '/path/to/local.jpg' }
async function uploadToCloudinary(source) {
  const form = new FormData();
  if (typeof source === 'string') {
    form.append('file', source); // Cloudinary fetches the remote URL itself
  } else {
    form.append('file', new Blob([fs.readFileSync(source.file)]), path.basename(source.file));
  }
  form.append('upload_preset', PRESET);
  form.append('folder', 'eventpulse/banners');
  form.append('tags', 'eventpulse-seed');

  const res = await fetch(`https://api.cloudinary.com/v1_1/${CLOUD}/image/upload`, {
    method: 'POST',
    body: form,
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(body?.error?.message || `Cloudinary upload failed (${res.status})`);
  }
  // Ask Cloudinary for an optimized delivery version (smaller, faster in the app).
  return body.secure_url.replace('/upload/', '/upload/f_auto,q_auto,w_1200/');
}

/** Local file if available, else the online sample; if that fails too, a reliable placeholder photo. */
async function uploadBanner(e, index) {
  const locals = localImages(e.category_slug);
  if (locals.length) {
    return uploadToCloudinary({ file: locals[index % locals.length] });
  }
  try {
    return await uploadToCloudinary(e.image);
  } catch (err) {
    console.log(`(sample image failed: ${err.message}; using placeholder photo)`);
    return uploadToCloudinary(`https://picsum.photos/seed/eventpulse-${e.id}/1200/675`);
  }
}

function eventDate(daysFromNow, hour) {
  const d = new Date();
  d.setDate(d.getDate() + daysFromNow);
  d.setHours(hour, 0, 0, 0);
  return d;
}

const pad = (n) => String(n).padStart(2, '0');

async function deleteTicketsFor(eventId) {
  const tickets = await db.collection('tickets').where('eventId', '==', eventId).get();
  await Promise.all(tickets.docs.map((t) => t.ref.delete()));
}

async function wipeSeeded() {
  const { FieldPath } = require('firebase-admin/firestore');
  const snap = await db
    .collection('events')
    .orderBy(FieldPath.documentId())
    .startAt('seed_')
    .endAt('seed_\uf8ff')
    .get();
  for (const d of snap.docs) {
    await deleteTicketsFor(d.id);
    await d.ref.delete();
    console.log(`  🗑 removed ${d.id}  ${d.data().title || ''}`);
  }
  console.log(`\nRemoved ${snap.size} seeded event(s). Events you created in the app are untouched.`);
}

async function main() {
  if (WIPE) return wipeSeeded();

  // 1. Find the organizer account
  let authUser;
  try {
    authUser = await getAuth().getUserByEmail(ORGANIZER_EMAIL);
  } catch {
    fail(`No account found for ${ORGANIZER_EMAIL}. Register it in the app first.`);
  }
  const profileSnap = await db.collection('users').doc(authUser.uid).get();
  if (!profileSnap.exists) {
    fail('That account has no profile yet. Sign in to the app once with it, then run this again.');
  }
  const profile = profileSnap.data();
  if (profile.role !== 'organizer' && profile.role !== 'admin') {
    console.warn(
      `⚠ ${ORGANIZER_EMAIL} has role "${profile.role}". Events will be created, but only an organizer or admin ` +
      'can see them in the dashboard. Approve its application (or set role to organizer) first.',
    );
  }
  console.log(`Organizer: ${profile.name || ORGANIZER_EMAIL} (${authUser.uid})${RESET ? '  [--reset]' : ''}\n`);

  // 2. Build the full list (hand-written + random)
  const all = [
    ...EVENTS.map((e) => ({
      ...e,
      id: `seed_evt_${pad(e.n)}`,
      code: `EP-EVT-SEED${pad(e.n)}`,
      category_slug: slug(e.category),
    })),
    ...buildRandomEvents(RANDOM_COUNT),
  ];

  // 3. Upload banners + write events
  let index = 0;
  for (const e of all) {
    const id = e.id;
    const ref = db.collection('events').doc(id);
    const existing = await ref.get();

    // Reuse a banner that's already on Cloudinary
    let imageUrl = existing.exists ? existing.data().imageUrl : '';
    if (!imageUrl || !imageUrl.includes('res.cloudinary.com')) {
      process.stdout.write(`  ↑ banner for "${e.title}" ... `);
      imageUrl = await uploadBanner(e, index);
      console.log('ok');
    }
    index++;

    const when = eventDate(e.daysFromNow, e.hour);
    const isNew = !existing.exists;

    const data = {
      id,
      title: e.title,
      description: e.description,
      category: e.category,
      dateTime: when.toISOString(),
      date: when.toISOString().split('T')[0],
      time: `${pad(when.getHours())}:${pad(when.getMinutes())}`,
      location: e.location,
      venueName: e.venueName,
      imageUrl,
      bannerUrl: imageUrl,
      organizerId: authUser.uid,
      organizerName: profile.name || 'Event Organizer',
      organizerAvatar: profile.avatarUrl || profile.avatar || '',
      organizerEmail: authUser.email,
      capacity: e.capacity,
      price: e.price,
      status: 'upcoming',
      tags: e.tags,
      registrationCode: e.code,
      isVirtual: false,
      meetingLink: null,
      rejectionReason: null,
    };

    // Only set these on first insert (or --reset), so a rehearsal never gets undone by re-running.
    if (isNew || RESET) {
      data.registeredCount = 0;
      data.approvalStatus = e.approved ? 'approved' : 'pending';
    }

    await ref.set(data, { merge: true });

    if (RESET) await deleteTicketsFor(id);

    const state = isNew || RESET ? (e.approved ? 'approved' : 'pending ') : 'kept    ';
    console.log(`  ✓ ${id}  [${state}]  ${e.title}`);
  }

  // 4. Read back and check the fields the app needs for registration
  let problems = 0;
  for (const e of all) {
    const d = (await db.collection('events').doc(e.id).get()).data() || {};
    const bad = [];
    if (typeof d.capacity !== 'number' || d.capacity < 1) bad.push('capacity');
    if (typeof d.registeredCount !== 'number') bad.push('registeredCount');
    if (!['approved', 'pending', 'rejected'].includes(d.approvalStatus)) bad.push('approvalStatus');
    if (!d.organizerId) bad.push('organizerId');
    if (!d.imageUrl || !d.imageUrl.includes('res.cloudinary.com')) bad.push('imageUrl (not on Cloudinary)');
    if (bad.length) { problems++; console.warn(`  ⚠ ${e.id}: check ${bad.join(', ')}`); }
  }
  console.log(problems ? `\n${problems} event(s) need attention (see above).` : '\nAll events verified: ready for RSVP.');

  console.log(`\nDone: ${all.length} events. Approved events are visible to everyone; pending ones show in the admin tab.`);
}

main().catch((err) => fail(err.message || String(err)));

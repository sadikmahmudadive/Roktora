// Seeds the Firebase emulators with the dashboard's sample data so it can be explored offline.
//
//   firebase emulators:start --only auth,firestore --project demo-roktora   (repo root, separate terminal)
//   npm run seed:emulator
//   npm run dev:emulator
//
// Sign in with  staff@demo.test / secret123  (hospital admin)  or  plain@demo.test / secret123  (no staff access).

const AUTH = "http://127.0.0.1:9099";
const FS = "http://127.0.0.1:8080/v1/projects/demo-roktora/databases/(default)/documents";
const DAY = 86_400_000;
const now = Date.now();
const ago = (ms) => new Date(now - ms);
const ahead = (ms) => new Date(now + ms);

async function signUp(email, password) {
  const res = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const body = await res.json();
  if (!body.localId) throw new Error(`signUp failed for ${email}: ${JSON.stringify(body)}`);
  return body.localId;
}

function value(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === "string") return { stringValue: v };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, value(x)])) } };
}

// "Bearer owner" bypasses security rules in the emulator, like the Admin SDK would.
async function put(path, data) {
  const res = await fetch(`${FS}/${path}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", authorization: "Bearer owner" },
    body: JSON.stringify({ fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, value(v)])) }),
  });
  if (!res.ok) throw new Error(`PUT ${path} failed: ${res.status} ${await res.text()}`);
}

const staffUid = await signUp("staff@demo.test", "secret123");
await signUp("plain@demo.test", "secret123");

const donorDefs = [
  ["sk", "Sadia Khan", "O−", "Pallabi", 3, 40],
  ["fh", "Farhan Hossain", "O−", "Mirpur 10", 7, 200],
  ["nr", "Nusrat Rahman", "B−", "Mirpur 2", 1, 200],
  ["ts", "Tania Sultana", "O+", "Mirpur 1", 9, 1],
  ["mr", "Mahmud Rahim", "B+", "Mirpur 12", 5, 250],
  ["ai", "Ayesha Islam", "A+", "Shewrapara", 2, 1],
  ["jh", "Jamal Hasan", "AB+", "Pallabi", 0, null],
  ["rm", "Rafiq Mia", "B−", "Kazipara", 12, 78],
  ["ka", "Kamrul Alam", "A−", "Agargaon", 6, 270],
];
const uids = {};
for (const [key, name, group, area, donations, lastDaysAgo] of donorDefs) {
  const uid = await signUp(`${key}@demo.test`, "secret123");
  uids[key] = uid;
  await put(`users/${uid}`, { name, area, bloodGroup: group, donations, available: true, eligible: true, ...(lastDaysAgo ? { lastDonation: ago(lastDaysAgo * DAY) } : {}) });
}

const superUid = await signUp("super@demo.test", "secret123");
await put(`accounts/${superUid}`, { email: "super@demo.test", displayName: "Platform Team", role: "superadmin" });
await put(`accounts/${staffUid}`, { email: "staff@demo.test", displayName: "Dr. Sultana", role: "admin", hospitalId: "mch" });
await put("hospitals/mch", {
  name: "Mirpur Central Hospital",
  address: "Section 10, Mirpur, Dhaka 1216",
  phone: "+880 2 9000 000",
  about: "Central blood bank serving Mirpur, Pallabi and Kafrul. Open 24 hours for emergencies.",
  verified: true,
  steps: [
    { label: "Documents submitted", when: "12 Feb 2026", done: true },
    { label: "DGHS license verified", when: "20 Feb 2026", done: true },
    { label: "Site visit by Roktora", when: "3 Mar 2026", done: true },
    { label: "Annual renewal", when: "Due 3 Mar 2027", done: false },
  ],
  docs: [
    { name: "DGHS blood bank license", status: "Verified", warning: false },
    { name: "Trade license", status: "Verified", warning: false },
    { name: "Fire safety certificate", status: "Expires in 40 days", warning: true },
  ],
  staff: [
    { name: "Dr. Sultana", role: "Admin · blood bank lead", twoFa: true },
    { name: "Rafi M.", role: "Staff · inventory", twoFa: true },
    { name: "Emergency desk", role: "Shared · post requests only", twoFa: true },
  ],
});

const stock = { "A+": [42, 50], "A−": [6, 12], "B+": [51, 55], "B−": [3, 12], "O+": [58, 60], "O−": [4, 15], "AB+": [18, 20], "AB−": [5, 8] };
for (const [group, [units, target]] of Object.entries(stock)) {
  const a = Math.round(units * 0.45), b = Math.round(units * 0.3), c = Math.round(units * 0.18);
  await put(`hospitals/mch/inventory/${group}`, { target, whole: a, red: b, plasma: c, platelets: units - a - b - c });
}

const batches = [
  ["MCH-24-10-0412", "O+", "Platelets", 1, 5], ["MCH-24-10-0398", "AB+", "Platelets", 2, 5], ["MCH-24-09-0255", "A+", "Red cells", 3, 42],
  ["MCH-24-09-0261", "B+", "Whole blood", 4, 35], ["MCH-24-09-0270", "O+", "Whole blood", 5, 35], ["MCH-24-09-0288", "A−", "Red cells", 6, 42],
];
for (const [id, group, component, days, life] of batches) {
  await put(`hospitals/mch/batches/${id}`, { group, component, expiresAt: ahead(days * DAY - 3_600_000), shelfLifeDays: life });
}

const requests = [
  ["h1", "O−", "3 bags for cardiac surgery", "critical", 3, ahead(3 * 3_600_000), ["sk", "fh"], "Ward 4", ago(2 * 3_600_000)],
  ["h2", "B−", "Restock for weekend surgeries", "urgent", 4, ahead(3 * DAY), ["nr"], "Blood bank", ago(40 * 60_000)],
  ["h3", "O+", "6 bags, road accident trauma", "urgent", 6, ahead(8 * 3_600_000), ["ts", "mr", "ai", "jh"], "Emergency", ago(5 * 3_600_000)],
  ["h4", "A+", "Thalassemia day-care", "routine", 2, ahead(4 * DAY), [], "Pediatrics · recurring", ago(DAY)],
];
for (const [id, group, title, urgency, need, deadline, committed, note, created] of requests) {
  await put(`requests/${id}`, {
    bloodGroup: group, title, place: "Mirpur Central Hospital", note, postedBy: "Mirpur Central Hospital", distanceKm: 0, bagsNeeded: need, urgency,
    deadline, verified: true, committedUids: committed.map((k) => uids[k]), status: "open", hospitalId: "mch", createdBy: staffUid, createdAt: created,
  });
}

const checkins = [
  ["Nusrat R.", "O−", "waiting", 20 * 60_000, null], ["Tania S.", "O+", "donating", 50 * 60_000, 1],
  ["Mahmud R.", "B+", "donating", 35 * 60_000, 5], ["Kamrul A.", "A−", "screening", 10 * 60_000, null],
];
let i = 0;
for (const [name, group, status, agoMs, bay] of checkins) {
  await put(`hospitals/mch/checkins/seed${i++}`, { donorName: name, group, status, at: ago(agoMs), donorUid: "", requestId: "", ...(bay ? { bay } : {}) });
}
// History so Reports has shape: roughly three donations a week, an occasional deferral.
const groups = ["O+", "B+", "A+", "O+", "AB+", "O−", "B−", "A+"];
for (let n = 0; n < 60; n++) {
  await put(`hospitals/mch/checkins/old${n}`, { donorName: `Donor ${n}`, group: groups[n % 8], status: n % 11 === 0 ? "deferred" : "done", at: ago((8 + n * 1.4) * DAY), donorUid: "", requestId: "" });
}
await put("requests/h0", { bloodGroup: "A+", title: "Fulfilled earlier", place: "Mirpur Central Hospital", note: "", postedBy: "Mirpur Central Hospital", distanceKm: 0, bagsNeeded: 2, urgency: "urgent", deadline: ago(2 * DAY), verified: true, committedUids: [], status: "fulfilled", hospitalId: "mch", createdBy: staffUid, createdAt: ago(3 * DAY), fulfilledAt: ago(3 * DAY - 4 * 3_600_000) });

console.log("Seeded. Sign in with staff@demo.test / secret123 (admin) plain@demo.test / secret123 (no access) or super@demo.test / secret123 (platform console).");

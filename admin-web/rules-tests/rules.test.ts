import { assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { arrayRemove, arrayUnion, doc, getDoc, serverTimestamp, setDoc, Timestamp, updateDoc, addDoc, collection, deleteDoc, getDocs, query, where } from "firebase/firestore";
import { readFileSync } from "node:fs";
import path from "node:path";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";

let env: RulesTestEnvironment;

const hostPort = (process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080").split(":");

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-roktora",
    firestore: { rules: readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8"), host: hostPort[0], port: Number(hostPort[1]) },
  });
});

afterAll(async () => {
  await env.cleanup();
});

/** Seeds the world with rules disabled: two hospitals, an admin and a staff member for each, donors. */
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "accounts/admin1"), { hospitalId: "mch", displayName: "Dr. Sultana", role: "admin" });
    await setDoc(doc(db, "accounts/staff1"), { hospitalId: "mch", displayName: "Rafi", role: "staff" });
    await setDoc(doc(db, "accounts/other1"), { hospitalId: "sq", displayName: "Other admin", role: "admin" });
    await setDoc(doc(db, "accounts/donor1"), { email: "d1@x.test", role: "user" });
    await setDoc(doc(db, "accounts/super1"), { email: "boss@x.test", role: "superadmin" });
    await setDoc(doc(db, "accounts/super2"), { email: "boss2@x.test", role: "superadmin" });
    await setDoc(doc(db, "hospitals/mch"), { name: "Mirpur Central", verified: true });
    await setDoc(doc(db, "hospitals/sq"), { name: "Square", verified: true });
    await setDoc(doc(db, "hospitals/mch/inventory/A+"), { target: 40, whole: 5 });
    await setDoc(doc(db, "users/donor1"), { name: "Farhan Hossain", area: "Mirpur", bloodGroup: "O+", donations: 2 });
    await setDoc(doc(db, "users/donor2"), { name: "Sadia Khan", area: "Pallabi", bloodGroup: "B+", donations: 0 });
    await setDoc(doc(db, "donors/donor1"), { publicName: "Farhan H.", bloodGroup: "O+", area: "Mirpur", available: true, donations: 2 });
    await setDoc(doc(db, "requests/hospReq"), {
      bloodGroup: "O+", title: "3 bags", bagsNeeded: 3, verified: true, committedUids: ["donor1"], status: "open", hospitalId: "mch", createdBy: "admin1",
    });
    await setDoc(doc(db, "requests/indivReq"), {
      bloodGroup: "A+", title: "For my father", bagsNeeded: 2, verified: false, committedUids: [], status: "open", createdBy: "donor2",
    });
  });
});

const as = (uid: string) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe("sign-in requirement", () => {
  it("anonymous visitors can read nothing", async () => {
    await assertFails(getDoc(doc(anon(), "requests/hospReq")));
    await assertFails(getDoc(doc(anon(), "hospitals/mch")));
    await assertFails(getDoc(doc(anon(), "donors/donor1")));
  });
});

describe("donor profiles", () => {
  it("a donor reads and writes only their own private profile", async () => {
    await assertSucceeds(getDoc(doc(as("donor1"), "users/donor1")));
    await assertSucceeds(updateDoc(doc(as("donor1"), "users/donor1"), { area: "Uttara" }));
    await assertFails(getDoc(doc(as("donor1"), "users/donor2")));
    await assertFails(updateDoc(doc(as("donor1"), "users/donor2"), { area: "x" }));
  });

  it("a donor can delete their own account data but not someone else's", async () => {
    await assertSucceeds(deleteDoc(doc(as("donor1"), "users/donor1")));
    await assertFails(deleteDoc(doc(as("donor1"), "users/donor2")));
  });

  it("the public donor directory is readable by signed-in users but only the owner can write it", async () => {
    await assertSucceeds(getDoc(doc(as("donor2"), "donors/donor1")));
    await assertFails(setDoc(doc(as("donor2"), "donors/donor1"), { publicName: "Hacked", bloodGroup: "O+", area: "x", available: true, donations: 99 }));
    await assertSucceeds(setDoc(doc(as("donor1"), "donors/donor1"), { publicName: "Farhan H.", bloodGroup: "O+", area: "Mirpur", available: false, donations: 2 }));
  });

  it("the public directory refuses private fields like the last donation date", async () => {
    await assertFails(setDoc(doc(as("donor1"), "donors/donor1"), { publicName: "Farhan H.", bloodGroup: "O+", area: "Mirpur", available: true, donations: 2, lastDonation: Timestamp.now() }));
  });
});

describe("superadmins", () => {
  it("can read every account and link someone to a hospital as admin or staff", async () => {
    const db = as("super1");
    await assertSucceeds(getDoc(doc(db, "accounts/donor1")));
    await assertSucceeds(getDocs(collection(db, "accounts")));
    await assertSucceeds(updateDoc(doc(db, "accounts/donor1"), { role: "staff", hospitalId: "mch" }));
    await assertSucceeds(updateDoc(doc(db, "accounts/donor1"), { role: "user", hospitalId: "" }));
  });

  it("cannot mint superadmins, edit other superadmins, or change anything but role and hospital", async () => {
    const db = as("super1");
    await assertFails(updateDoc(doc(db, "accounts/donor1"), { role: "superadmin" }));
    await assertFails(updateDoc(doc(db, "accounts/super2"), { role: "user" }));
    await assertFails(updateDoc(doc(db, "accounts/super1"), { role: "user" }));
    await assertFails(updateDoc(doc(db, "accounts/donor1"), { email: "evil@x.test" }));
  });

  it("can create, verify and edit hospitals; hospital admins cannot verify themselves", async () => {
    await assertSucceeds(setDoc(doc(as("super1"), "hospitals/new"), { name: "New Hospital", verified: false }));
    await assertSucceeds(updateDoc(doc(as("super1"), "hospitals/new"), { verified: true }));
    await assertFails(updateDoc(doc(as("admin1"), "hospitals/mch"), { verified: false }));
    await assertFails(setDoc(doc(as("admin1"), "hospitals/another"), { name: "Fake" }));
    await assertFails(setDoc(doc(as("donor1"), "hospitals/another"), { name: "Fake" }));
  });

  it("a hospital admin can create their own unverified profile once, but not self-verify or use another id", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "accounts/newadmin"), { role: "admin", hospitalId: "fresh" });
      await setDoc(doc(ctx.firestore(), "accounts/newstaff"), { role: "staff", hospitalId: "fresh" });
    });
    await assertFails(setDoc(doc(as("newadmin"), "hospitals/fresh"), { name: "x", verified: true }));
    await assertFails(setDoc(doc(as("newadmin"), "hospitals/other"), { name: "x" }));
    await assertFails(setDoc(doc(as("newstaff"), "hospitals/fresh"), { name: "x" }));
    await assertSucceeds(setDoc(doc(as("newadmin"), "hospitals/fresh"), { name: "x", address: "", phone: "", about: "" }));
  });

  it("do not get donor profiles or hospital stock from the role alone", async () => {
    await assertFails(getDoc(doc(as("super1"), "users/donor1")));
    await assertFails(getDoc(doc(as("super1"), "hospitals/mch/inventory/A+")));
  });

  it("ordinary people and hospital admins cannot read others' accounts or change roles", async () => {
    await assertFails(getDoc(doc(as("admin1"), "accounts/donor1")));
    await assertFails(updateDoc(doc(as("admin1"), "accounts/donor1"), { role: "staff", hospitalId: "mch" }));
  });
});

describe("hospital staff", () => {
  it("staff can read donor profiles; ordinary donors cannot", async () => {
    await assertSucceeds(getDoc(doc(as("staff1"), "users/donor1")));
    await assertSucceeds(getDocs(query(collection(as("admin1"), "users"))));
    await assertFails(getDoc(doc(as("donor2"), "users/donor1")));
  });

  it("staff can record a completed donation but cannot edit anything else on a donor", async () => {
    const db = as("staff1");
    await assertSucceeds(updateDoc(doc(db, "users/donor1"), { donations: 3, lastDonation: Timestamp.now() }));
    await assertSucceeds(addDoc(collection(db, "users/donor1/donations"), { date: Timestamp.now(), place: "Mirpur Central", note: "Whole blood", status: "donated" }));
    await assertFails(updateDoc(doc(db, "users/donor1"), { name: "Renamed" }));
    await assertFails(updateDoc(doc(db, "users/donor1"), { bloodGroup: "AB-" }));
  });

  it("staff can rest a donor in the public directory but not change who they are", async () => {
    await assertSucceeds(updateDoc(doc(as("staff1"), "donors/donor1"), { donations: 3, available: false }));
    await assertFails(updateDoc(doc(as("staff1"), "donors/donor1"), { publicName: "Someone Else" }));
  });

  it("a donor cannot grant themselves staff access", async () => {
    await assertFails(updateDoc(doc(as("donor1"), "accounts/donor1"), { role: "admin" }));
    await assertFails(updateDoc(doc(as("donor1"), "accounts/donor1"), { hospitalId: "mch" }));
    await assertFails(setDoc(doc(as("donor2"), "accounts/donor2"), { email: "x", role: "admin" }));
    await assertFails(setDoc(doc(as("donor2"), "accounts/donor2"), { email: "x", role: "user", hospitalId: "mch" }));
    await assertFails(setDoc(doc(as("admin1"), "accounts/newguy"), { role: "admin", hospitalId: "mch" }));
  });

  it("a new sign-in creates a plain user account and later logins refresh only login info", async () => {
    await assertSucceeds(setDoc(doc(as("donor2"), "accounts/donor2"), { email: "d2@x.test", role: "user", createdAt: Timestamp.now() }));
    await assertSucceeds(updateDoc(doc(as("admin1"), "accounts/admin1"), { email: "a@x.test", lastLoginAt: Timestamp.now() }));
    await assertSucceeds(updateDoc(doc(as("donor1"), "accounts/donor1"), { lastLoginAt: Timestamp.now(), providers: ["password"] }));
  });

  it("people can read only their own account record", async () => {
    await assertSucceeds(getDoc(doc(as("admin1"), "accounts/admin1")));
    await assertFails(getDoc(doc(as("admin1"), "accounts/staff1")));
    await assertFails(getDoc(doc(as("donor1"), "accounts/admin1")));
  });

  it("staff can send a donor an inbox message; the donor can read it and mark it read, but not edit it", async () => {
    await assertSucceeds(addDoc(collection(as("staff1"), "users/donor1/inbox"), { title: "Hi", body: "We need O+", from: "Mirpur Central", at: Timestamp.now(), read: false }));
    await assertFails(addDoc(collection(as("donor2"), "users/donor1/inbox"), { title: "Spam", body: "x", from: "x", at: Timestamp.now(), read: false }));

    let id = "";
    await env.withSecurityRulesDisabled(async (ctx) => {
      id = (await addDoc(collection(ctx.firestore(), "users/donor1/inbox"), { title: "T", body: "B", from: "F", at: Timestamp.now(), read: false })).id;
    });
    await assertSucceeds(getDoc(doc(as("donor1"), `users/donor1/inbox/${id}`)));
    await assertFails(getDoc(doc(as("donor2"), `users/donor1/inbox/${id}`)));
    await assertSucceeds(updateDoc(doc(as("donor1"), `users/donor1/inbox/${id}`), { read: true }));
    await assertFails(updateDoc(doc(as("donor1"), `users/donor1/inbox/${id}`), { body: "edited" }));
  });
});

describe("hospital data", () => {
  it("any signed-in user can read a hospital's public profile", async () => {
    await assertSucceeds(getDoc(doc(as("donor1"), "hospitals/mch")));
  });

  it("only that hospital's staff touch its inventory, batches and check-ins", async () => {
    await assertSucceeds(setDoc(doc(as("staff1"), "hospitals/mch/inventory/A+"), { whole: 6 }, { merge: true }));
    await assertSucceeds(addDoc(collection(as("staff1"), "hospitals/mch/checkins"), { donorName: "Karim", group: "B+", status: "donating", at: Timestamp.now() }));
    await assertSucceeds(getDoc(doc(as("staff1"), "hospitals/mch/inventory/A+")));

    await assertFails(setDoc(doc(as("other1"), "hospitals/mch/inventory/A+"), { whole: 999 }, { merge: true }));
    await assertFails(getDoc(doc(as("other1"), "hospitals/mch/inventory/A+")));
    await assertFails(setDoc(doc(as("donor1"), "hospitals/mch/inventory/A+"), { whole: 999 }, { merge: true }));
    await assertFails(getDoc(doc(as("donor1"), "hospitals/mch/inventory/A+")));
  });

  it("only hospital admins, not plain staff, edit the public profile", async () => {
    await assertSucceeds(updateDoc(doc(as("admin1"), "hospitals/mch"), { phone: "+880 2 123" }));
    await assertFails(updateDoc(doc(as("staff1"), "hospitals/mch"), { phone: "+880 2 123" }));
    await assertFails(updateDoc(doc(as("other1"), "hospitals/mch"), { phone: "+880 2 123" }));
  });
});

describe("blood requests", () => {
  const base = { bloodGroup: "A+", title: "2 bags", bagsNeeded: 2, committedUids: [] as string[], status: "open" };

  it("individuals can post an unverified request as themselves", async () => {
    await assertSucceeds(addDoc(collection(as("donor1"), "requests"), { ...base, verified: false, createdBy: "donor1", createdAt: serverTimestamp() }));
  });

  it("individuals cannot post as verified, as someone else, as a hospital, or pre-committed", async () => {
    const db = as("donor1");
    await assertFails(addDoc(collection(db, "requests"), { ...base, verified: true, createdBy: "donor1" }));
    await assertFails(addDoc(collection(db, "requests"), { ...base, verified: false, createdBy: "donor2" }));
    await assertFails(addDoc(collection(db, "requests"), { ...base, verified: false, createdBy: "donor1", hospitalId: "mch" }));
    await assertFails(addDoc(collection(db, "requests"), { ...base, verified: false, createdBy: "donor1", committedUids: ["donor2"] }));
    await assertFails(addDoc(collection(db, "requests"), { ...base, bagsNeeded: 500, verified: false, createdBy: "donor1" }));
  });

  it("staff post verified requests for their own hospital only", async () => {
    await assertSucceeds(addDoc(collection(as("staff1"), "requests"), { ...base, verified: true, hospitalId: "mch", createdBy: "staff1" }));
    await assertFails(addDoc(collection(as("staff1"), "requests"), { ...base, verified: true, hospitalId: "sq", createdBy: "staff1" }));
    await assertFails(addDoc(collection(as("donor1"), "requests"), { ...base, verified: true, hospitalId: "mch", createdBy: "donor1" }));
  });

  it("a donor can commit and un-commit themselves, but not another donor", async () => {
    // donor1 is already committed to hospReq. Removing them is someone else's doing: denied.
    await assertFails(updateDoc(doc(as("donor2"), "requests/hospReq"), { committedUids: arrayRemove("donor1") }));
    // Adding a different person than yourself is denied too.
    await assertFails(updateDoc(doc(as("donor2"), "requests/hospReq"), { committedUids: arrayUnion("donor1x") }));
    // Committing and withdrawing yourself is fine.
    await assertSucceeds(updateDoc(doc(as("donor2"), "requests/hospReq"), { committedUids: arrayUnion("donor2") }));
    await assertSucceeds(updateDoc(doc(as("donor1"), "requests/hospReq"), { committedUids: arrayRemove("donor1") }));
  });

  it("a donor cannot rewrite a request's details while committing", async () => {
    await assertFails(updateDoc(doc(as("donor2"), "requests/hospReq"), { committedUids: arrayUnion("donor2"), title: "Changed" }));
  });

  it("the poster can mark their request fulfilled; strangers cannot", async () => {
    await assertSucceeds(updateDoc(doc(as("donor2"), "requests/indivReq"), { status: "fulfilled", fulfilledAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as("donor1"), "requests/indivReq"), { status: "closed" }));
    await assertFails(updateDoc(doc(as("donor2"), "requests/indivReq"), { status: "bogus" }));
  });

  it("hospital staff can close their hospital's requests but not another hospital's", async () => {
    await assertSucceeds(updateDoc(doc(as("staff1"), "requests/hospReq"), { status: "fulfilled", fulfilledAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as("other1"), "requests/hospReq"), { status: "closed" }));
  });

  it("a hospital request cannot be queried by someone outside it for private data, but is readable as a feed", async () => {
    await assertSucceeds(getDocs(query(collection(as("donor1"), "requests"), where("hospitalId", "==", "mch"))));
  });
});

describe("chat and reports", () => {
  it("only committed donors and the requester can read or write a request's chat", async () => {
    const msg = { fromUid: "donor1", text: "On my way", senderName: "Farhan H.", sentAt: serverTimestamp() };
    await assertSucceeds(addDoc(collection(as("donor1"), "requests/hospReq/messages"), msg)); // committed
    await assertSucceeds(addDoc(collection(as("admin1"), "requests/hospReq/messages"), { ...msg, fromUid: "admin1" })); // requester
    await assertSucceeds(addDoc(collection(as("staff1"), "requests/hospReq/messages"), { ...msg, fromUid: "staff1" })); // hospital staff
    await assertFails(addDoc(collection(as("other1"), "requests/hospReq/messages"), { ...msg, fromUid: "other1" })); // another hospital
    await assertFails(addDoc(collection(as("donor2"), "requests/hospReq/messages"), { ...msg, fromUid: "donor2" })); // outsider
    await assertFails(addDoc(collection(as("donor1"), "requests/hospReq/messages"), { ...msg, fromUid: "donor2" })); // spoofed sender
  });

  it("messages must be server-stamped, well formed, and only while the request is open", async () => {
    const db = as("donor1");
    const ok = { fromUid: "donor1", text: "hi", sentAt: serverTimestamp() };
    await assertFails(addDoc(collection(db, "requests/hospReq/messages"), { ...ok, sentAt: Timestamp.fromMillis(1000) })); // backdated
    await assertFails(addDoc(collection(db, "requests/hospReq/messages"), { ...ok, text: "" }));
    await assertFails(addDoc(collection(db, "requests/hospReq/messages"), { ...ok, text: "x".repeat(1001) }));
    await assertFails(addDoc(collection(db, "requests/hospReq/messages"), { ...ok, extra: "nope" }));
    await assertFails(addDoc(collection(db, "requests/hospReq/messages"), { ...ok, kind: "location" })); // location needs coordinates
    await assertSucceeds(addDoc(collection(db, "requests/hospReq/messages"), { ...ok, kind: "location", lat: 23.75, lng: 90.37, text: "Mirpur 10" }));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), "requests/hospReq"), { status: "fulfilled" });
    });
    await assertFails(addDoc(collection(db, "requests/hospReq/messages"), ok)); // closed
    await assertSucceeds(getDocs(collection(db, "requests/hospReq/messages"))); // history stays readable
  });

  it("a user keeps their own chat read markers private", async () => {
    await assertSucceeds(setDoc(doc(as("donor1"), "users/donor1/chatReads/hospReq"), { readAt: serverTimestamp() }));
    await assertFails(getDoc(doc(as("donor2"), "users/donor1/chatReads/hospReq")));
    await assertFails(setDoc(doc(as("donor2"), "users/donor1/chatReads/hospReq"), { readAt: serverTimestamp() }));
  });

  it("anyone signed in can file a report, but nobody can read them back", async () => {
    await assertSucceeds(addDoc(collection(as("donor1"), "reports"), { requestId: "hospReq", reason: "Asked for money", reportedBy: "donor1", createdAt: serverTimestamp() }));
    await assertFails(addDoc(collection(as("donor1"), "reports"), { requestId: "hospReq", reason: "x", reportedBy: "donor2" }));
    await assertFails(getDocs(collection(as("admin1"), "reports")));
  });
});

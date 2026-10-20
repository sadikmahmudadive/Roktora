# Roktora Admin

The hospital blood-bank dashboard for Roktora. A Next.js (App Router) web app that uses the **same
Firebase project and Firestore data** as the mobile app.

- Sign in with **email + password** or **Google** (plus password reset).
- Screens: Dashboard, Inventory, Requests, Check-in, Donors, Reports, Hospital profile.
- Light/dark themes, responsive from phone to desktop.

## 1. Run it locally

```bash
cd admin-web
npm install
cp .env.local.example .env.local   # then fill in the values (step 2)
npm run dev                        # http://localhost:3000
```

Other scripts: `npm test` (unit + component tests), `npm run typecheck`, `npm run lint`, `npm run build`.

## 2. Connect Firebase

1. **Register a web app.** Firebase console -> Project settings -> General -> *Your apps* -> **Add app** -> Web.
   Copy the config values into `.env.local` (`apiKey`, `appId`, `messagingSenderId`; project ID and auth
   domain are pre-filled for the `roktora` project).
2. **Enable sign-in methods.** Authentication -> Sign-in method -> enable **Email/Password** and **Google**.
   Phone stays enabled for the mobile app. Both apps share one user list.
3. **Authorize the domain.** Authentication -> Settings -> **Authorized domains**: `localhost` is there by
   default; add your production domain when you deploy, or Google sign-in fails with
   `auth/unauthorized-domain`.
4. **Deploy the Firestore rules** from the repo root (the dashboard relies on the staff rules):

   ```bash
   firebase deploy --only firestore:rules --project roktora
   ```

## 3. Give someone access

Every sign-in (app or dashboard) automatically saves `accounts/{uid}` with `email`, `phone`, `displayName`,
`photoURL`, `providers`, `createdAt`, `lastLoginAt` and `role: "user"`. Clients can never write `role` or
`hospitalId`; only you can, in the console. To make someone hospital staff:

1. Create `hospitals/{hospitalId}` (for example `mch`) with fields `name`, `address`, `phone`, `about`,
   `verified` (boolean), or create it from the dashboard's Hospital profile page once you are an admin.
2. Open Firestore -> `accounts` -> the person's document (ID = their User UID; the dashboard's "isn't linked
   to a hospital" page shows it with a copy button) and set:
   - `role` (string): `admin` (can edit the hospital profile) or `staff`
   - `hospitalId` (string): `mch`
3. They reload the page and the dashboard opens. On first use, open **Inventory** and choose **Set up
   inventory**.

## Superadmins (the platform team)

A superadmin runs the whole platform from **/platform** (the "Platform console"): see every account, link
people to hospitals as `admin` or `staff` (or unlink them), add hospitals, and verify them. It is the only
way `verified` changes: hospital admins can edit their name, address, phone and about text, nothing else.

Superadmin is set **only in the Firebase console**: open `accounts/{uid}` and set `role` to `superadmin`
(no `hospitalId` needed). The console cannot be used to mint or edit another superadmin, so keep the team
list in the console. A superadmin does not get donor profiles or any hospital's stock from that role alone.
Redeploy the rules after pulling this change.

## Try it offline with the Firebase emulators

No real project needed. This runs the dashboard against local Auth and Firestore emulators (Java required)
with the same sample data as the design:

```bash
# terminal 1, from the repo root: runs the emulators with the repo's firestore.rules
firebase emulators:start --only auth,firestore --project demo-roktora

# terminal 2, from admin-web/
npm run seed:emulator   # creates demo users and hospital data
npm run dev:emulator    # http://localhost:3000
```

Sign in with `staff@demo.test` / `secret123` (hospital admin) or `plain@demo.test` / `secret123` (no staff access).

`npm run test:rules` checks the security rules (donors, staff, hospital data, requests, chat, reports) against
the Firestore emulator.

## 4. Deploy

Any Node host works. For Vercel, import the repo with **Root Directory** `admin-web` and add the six
`NEXT_PUBLIC_FIREBASE_*` variables. Then add the production domain to Firebase **Authorized domains**.

## How it fits together

| Piece | Where |
| --- | --- |
| Firebase init (reads `NEXT_PUBLIC_FIREBASE_*`) | `src/lib/firebase.ts` |
| Email + Google auth, staff-record lookup | `src/lib/auth.tsx`, `src/lib/auth-errors.ts` |
| Firestore live hooks and writes | `src/lib/store.ts` |
| Stock levels, eligibility, naming rules | `src/lib/models.ts` |
| Report calculations | `src/lib/report.ts` |
| Access guard + app shell | `src/components/guard.tsx`, `src/components/shell.tsx` |
| Screens | `src/app/(dash)/*`, `src/app/login` |

Design tokens (colours, radii) are the mobile app's, in `src/app/globals.css`.

## Notes

- Every dashboard screen is client-rendered and reads the clock only after mount (`useNow`), so nothing
  time-dependent is baked in at build time (the project uses Next's Cache Components).
- Donors appear to hospitals as first name + last initial only. Reports are aggregate; there are no
  per-donor figures.
- Sending a message from **Donors** writes to the donor's in-app inbox. Push notifications for it need
  the Cloud Function noted in the main project's docs.

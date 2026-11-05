/// <reference path="../pb_data/types.d.ts" />

// Sign-ups need the invite code from the SAMRIDHI_SIGNUP_CODE environment
// variable. Without it set (12+ characters), nobody can sign up (only a
// superuser can add accounts), so a fresh server is never open to the world
// by accident.
//
// Sharing a server with Artha? Do NOT copy this hook: Artha's own hook then
// governs sign-ups for the shared `users` collection (see README).
onRecordCreateRequest((e) => {
  if (e.hasSuperuserAuth()) {
    return e.next()
  }
  const expected = $os.getenv("SAMRIDHI_SIGNUP_CODE")
  const given = String(e.requestInfo().body["invite"] || "")
  if (expected.length < 12 || !$security.equal(given, expected)) {
    throw new ForbiddenError("Sign-up needs a valid invite code.")
  }
  return e.next()
}, "users")

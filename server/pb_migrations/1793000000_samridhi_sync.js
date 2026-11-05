/// <reference path="../pb_data/types.d.ts" />

// Samridhi sync schema. The server stores only ciphertext: each row of
// `sam_changes` is one whole-state snapshot, sealed on the device with the
// user's sync passphrase (Argon2id + XChaCha20-Poly1305). The unique
// (owner, seq) index is the concurrency control: of two devices pushing the
// same next number, the second is rejected and must pull first.
//
// Collections are prefixed `sam_` so this can share a PocketBase instance
// (and its `users` collection) with Artha without touching Artha's data.
migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  const own = "owner = @request.auth.id"
  const createOwn = "@request.auth.id != '' && @request.body.owner = @request.auth.id"

  // Append-only: no update or delete rule, so only a superuser can change history.
  app.save(new Collection({
    type: "base",
    name: "sam_changes",
    listRule: own,
    viewRule: own,
    createRule: createOwn,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "relation", name: "owner", required: true, maxSelect: 1, cascadeDelete: true, collectionId: users.id },
      { type: "text", name: "device", required: true, min: 32, max: 32, pattern: "^[0-9a-f]{32}$" },
      { type: "number", name: "seq", required: true, onlyInt: true, min: 1 },
      { type: "text", name: "payload", required: true, max: 2000000 },
      { type: "autodate", name: "created", onCreate: true },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_sam_changes_slot ON sam_changes (owner, seq)"],
  }))

  // Account hardening: password sign-in only, no listing of other users.
  users.oauth2.enabled = false
  users.otp.enabled = false
  users.listRule = "id = @request.auth.id"
  users.viewRule = "id = @request.auth.id"
  app.save(users)

  // Add our rate limits without clobbering ones another app already set.
  const settings = app.settings()
  if (settings.meta.appName === "Acme") {
    settings.meta.appName = "Samridhi Sync"
  }
  settings.batch.enabled = false
  settings.rateLimits.enabled = true
  const ours = [
    { label: "*:auth", audience: "", duration: 60, maxRequests: 10 },
    { label: "users:create", audience: "", duration: 3600, maxRequests: 5 },
    { label: "sam_changes:create", audience: "@auth", duration: 10, maxRequests: 30 },
    { label: "/api/", audience: "", duration: 10, maxRequests: 300 },
  ]
  const have = new Set(settings.rateLimits.rules.map((r) => r.label))
  settings.rateLimits.rules = settings.rateLimits.rules.concat(ours.filter((r) => !have.has(r.label)))
  app.save(settings)
}, (app) => {
  app.delete(app.findCollectionByNameOrId("sam_changes"))
})

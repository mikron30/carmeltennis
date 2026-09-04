"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");

const {
  ACCESS_LIFETIME_MILLISECONDS,
  accessTokenMatches,
  buildVideoAccessUrl,
  createManagerVideoAccessReissuer,
  createOpenVideoClipHandler,
  hashAccessToken,
  issueAccessToken,
  landingPage,
} = require("../src/video/access");
const {getVideoAccessSettings} = require("../src/video/config");

const NOW = new Date("2026-08-20T09:00:00.000Z");
const OBJECT_NAME = `video-clips/${"a".repeat(64)}.mp4`;
const PUBLIC_BASE_URL =
  "https://europe-west3-example.cloudfunctions.net/openVideoClip";

function deterministicAccess(byte = 0x61) {
  return issueAccessToken({randomBytes: () => Buffer.alloc(32, byte)});
}

function fakeDatabase(job, {exists = true} = {}) {
  const state = {
    collectionName: null,
    requestId: null,
    reads: 0,
    updates: [],
  };
  const reference = {
    async get() {
      state.reads += 1;
      return {exists, data: () => job};
    },
    async update(update) {
      state.updates.push(update);
    },
  };
  const db = {
    collection(name) {
      state.collectionName = name;
      return {
        doc(requestId) {
          state.requestId = requestId;
          return reference;
        },
      };
    },
  };
  return {db, state};
}

function fakeBucket({
  objectExists = true,
  signedUrls = ["https://storage.example.invalid/fresh-1"],
  metadata = {timeCreated: "2026-08-20T08:00:00.000Z"},
  metadataError = null,
} = {}) {
  const state = {
    objectNames: [],
    existsCalls: 0,
    signedUrlCalls: [],
    metadataCalls: 0,
  };
  const file = {
    async exists() {
      state.existsCalls += 1;
      return [objectExists];
    },
    async getSignedUrl(options) {
      state.signedUrlCalls.push(options);
      const index = state.signedUrlCalls.length - 1;
      return [signedUrls[index] || `https://storage.example.invalid/fresh-${index + 1}`];
    },
    async getMetadata() {
      state.metadataCalls += 1;
      if (metadataError) throw metadataError;
      return [metadata];
    },
  };
  return {
    bucket: {
      file(objectName) {
        state.objectNames.push(objectName);
        return file;
      },
    },
    state,
  };
}

class FakeResponse {
  constructor() {
    this.headers = {};
    this.statusCode = null;
    this.body = null;
  }

  set(nameOrFields, value) {
    if (typeof nameOrFields === "string") {
      this.headers[nameOrFields] = value;
    } else {
      Object.assign(this.headers, nameOrFields);
    }
    return this;
  }

  status(statusCode) {
    this.statusCode = statusCode;
    return this;
  }

  send(body) {
    this.body = body;
    return this;
  }

  redirect(statusCode, location) {
    this.statusCode = statusCode;
    this.headers.Location = location;
    return this;
  }
}

function quietLogger() {
  const entries = [];
  return {
    entries,
    info(message, fields) {
      entries.push({level: "info", message, fields});
    },
    error(message, fields) {
      entries.push({level: "error", message, fields});
    },
  };
}

function validJob(access, overrides = {}) {
  return {
    storageObject: OBJECT_NAME,
    accessTokenHashes: [access.tokenHash],
    accessExpiresAt: new Date(NOW.getTime() + (60 * 60 * 1000)),
    ...overrides,
  };
}

test("video access configuration defaults to seven days and fifteen minutes", () => {
  const settings = getVideoAccessSettings({
    VIDEO_CLIP_BUCKET: "unit-test-video-clips",
    VIDEO_PUBLIC_BASE_URL: PUBLIC_BASE_URL,
  });

  assert.equal(settings.accessTtlSeconds, 604800);
  assert.equal(settings.signedUrlTtlSeconds, 900);
  assert.equal(settings.videoClipBucket, "unit-test-video-clips");
});

test("video access configuration rejects an access lifetime over seven days", () => {
  assert.throws(
      () => getVideoAccessSettings({
        VIDEO_CLIP_BUCKET: "unit-test-video-clips",
        VIDEO_PUBLIC_BASE_URL: PUBLIC_BASE_URL,
        VIDEO_ACCESS_TTL_SECONDS: "604801",
      }),
      /cannot exceed seven days/,
  );
});

test("access token issuance requests exactly 32 cryptographically random bytes", () => {
  let requestedBytes = null;
  const entropy = Buffer.from(Array.from({length: 32}, (_, index) => index));

  const access = issueAccessToken({
    randomBytes(size) {
      requestedBytes = size;
      return entropy;
    },
  });

  assert.equal(requestedBytes, 32);
  assert.match(access.token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(Buffer.from(access.token, "base64url").length, 32);
  assert.equal(
      access.tokenHash,
      crypto.createHash("sha256").update(access.token, "utf8").digest("hex"),
  );
  assert.notEqual(access.tokenHash, access.token);
});

test("access token validation accepts a stored hash and rejects the wrong token", () => {
  const access = deterministicAccess(0x41);
  const wrong = deterministicAccess(0x42);

  assert.equal(accessTokenMatches(access.token, [access.tokenHash]), true);
  assert.equal(accessTokenMatches(wrong.token, [access.tokenHash]), false);
  assert.equal(accessTokenMatches("not-base64url", [access.tokenHash]), false);
});

test("video access URL keeps all authorization material out of the query", () => {
  const access = deterministicAccess();
  const result = new URL(buildVideoAccessUrl(
      PUBLIC_BASE_URL,
      "request-1",
      access.token,
  ));

  assert.equal(result.search, "");
  assert.equal(result.searchParams.has("token"), false);
  const fragment = new URLSearchParams(result.hash.slice(1));
  assert.equal(fragment.get("requestId"), "request-1");
  assert.equal(fragment.get("token"), access.token);
});

test("GET serves a no-store fragment-to-POST bootstrap without receiving a token", async () => {
  const access = deterministicAccess();
  const {db, state: databaseState} = fakeDatabase(validJob(access));
  const {bucket} = fakeBucket();
  const handler = createOpenVideoClipHandler({db, bucket});
  const response = new FakeResponse();

  await handler({method: "GET", query: {}}, response);

  assert.equal(response.statusCode, 200);
  assert.match(response.headers["Cache-Control"], /no-store/);
  assert.match(response.headers["Content-Security-Policy"], /script-src 'sha256-/);
  assert.match(response.body, /window\.location\.hash/);
  assert.match(response.body, /form\.method = "post"/);
  assert.equal(response.body.includes(access.token), false);
  assert.equal(databaseState.reads, 0);
  assert.equal(landingPage().includes("token="), false);
});

test("valid POST checks the private object and creates a fresh short-lived URL each time", async () => {
  const access = deterministicAccess();
  const {db, state: databaseState} = fakeDatabase(validJob(access));
  const {bucket, state: storageState} = fakeBucket({
    signedUrls: [
      "https://storage.example.invalid/fresh-1",
      "https://storage.example.invalid/fresh-2",
    ],
  });
  const logger = quietLogger();
  const handler = createOpenVideoClipHandler({
    db,
    bucket,
    clock: () => NOW,
    logger,
  });

  const firstResponse = new FakeResponse();
  await handler({
    method: "POST",
    rawBody: Buffer.from(new URLSearchParams({
      requestId: "request-1",
      token: access.token,
    }).toString()),
  }, firstResponse);
  const secondResponse = new FakeResponse();
  await handler({
    method: "POST",
    body: {requestId: "request-1", token: access.token},
  }, secondResponse);

  assert.equal(firstResponse.statusCode, 303);
  assert.equal(firstResponse.headers.Location, "https://storage.example.invalid/fresh-1");
  assert.equal(secondResponse.statusCode, 303);
  assert.equal(secondResponse.headers.Location, "https://storage.example.invalid/fresh-2");
  assert.equal(storageState.existsCalls, 2);
  assert.equal(storageState.signedUrlCalls.length, 2);
  assert.equal(
      storageState.signedUrlCalls[0].expires.toISOString(),
      "2026-08-20T09:15:00.000Z",
  );
  assert.equal(storageState.signedUrlCalls[0].version, "v4");
  assert.equal(storageState.signedUrlCalls[0].action, "read");
  assert.equal(databaseState.updates.length, 0);
  const logged = JSON.stringify(logger.entries);
  assert.equal(logged.includes(access.token), false);
  assert.equal(logged.includes("storage.example.invalid"), false);
});

test("fresh signed URL expiry is capped at the video's seven-day access expiry", async () => {
  const access = deterministicAccess();
  const accessExpiresAt = new Date(NOW.getTime() + (2 * 60 * 1000));
  const {db} = fakeDatabase(validJob(access, {accessExpiresAt}));
  const {bucket, state} = fakeBucket();
  const handler = createOpenVideoClipHandler({
    db,
    bucket,
    clock: () => NOW,
    logger: quietLogger(),
  });
  const response = new FakeResponse();

  await handler({
    method: "POST",
    body: {requestId: "request-1", token: access.token},
  }, response);

  assert.equal(response.statusCode, 303);
  assert.equal(state.signedUrlCalls[0].expires.toISOString(), accessExpiresAt.toISOString());
});

test("wrong token is rejected before checking Storage", async () => {
  const access = deterministicAccess(0x41);
  const wrong = deterministicAccess(0x42);
  const {db} = fakeDatabase(validJob(access));
  const {bucket, state} = fakeBucket();
  const handler = createOpenVideoClipHandler({db, bucket, clock: () => NOW});
  const response = new FakeResponse();

  await handler({
    method: "POST",
    body: {requestId: "request-1", token: wrong.token},
  }, response);

  assert.equal(response.statusCode, 404);
  assert.equal(state.existsCalls, 0);
  assert.equal(state.signedUrlCalls.length, 0);
});

test("expired video returns Gone before checking Storage", async () => {
  const access = deterministicAccess();
  const {db} = fakeDatabase(validJob(access, {
    accessExpiresAt: new Date(NOW.getTime() - 1),
  }));
  const {bucket, state} = fakeBucket();
  const handler = createOpenVideoClipHandler({db, bucket, clock: () => NOW});
  const response = new FakeResponse();

  await handler({
    method: "POST",
    body: {requestId: "request-1", token: access.token},
  }, response);

  assert.equal(response.statusCode, 410);
  assert.equal(state.existsCalls, 0);
});

test("missing private Storage object returns Not Found without signing", async () => {
  const access = deterministicAccess();
  const {db} = fakeDatabase(validJob(access));
  const {bucket, state} = fakeBucket({objectExists: false});
  const handler = createOpenVideoClipHandler({db, bucket, clock: () => NOW});
  const response = new FakeResponse();

  await handler({
    method: "POST",
    body: {requestId: "request-1", token: access.token},
  }, response);

  assert.equal(response.statusCode, 404);
  assert.equal(state.existsCalls, 1);
  assert.equal(state.signedUrlCalls.length, 0);
});

test("manager recovery appends only a token hash and does not enqueue or reprocess", async () => {
  const {db, state: databaseState} = fakeDatabase({
    status: "sent",
    storageObject: OBJECT_NAME,
    // Legacy request: no accessExpiresAt and only the old direct-link metadata.
    linkExpiresAt: new Date("2026-08-20T08:30:00.000Z"),
  });
  const {bucket, state: storageState} = fakeBucket({
    metadata: {timeCreated: "2026-08-19T09:00:00.000Z"},
  });
  const managerChecks = [];
  let randomByteRequest = null;
  const logger = quietLogger();
  const reissue = createManagerVideoAccessReissuer({
    db,
    bucket,
    publicBaseUrl: PUBLIC_BASE_URL,
    clock: () => NOW,
    randomBytes(size) {
      randomByteRequest = size;
      return Buffer.alloc(32, 0x7f);
    },
    arrayUnion(value) {
      return {operation: "arrayUnion", values: [value]};
    },
    async assertManager(request) {
      managerChecks.push(request.auth.uid);
    },
    logger,
  });

  const result = await reissue({
    auth: {uid: "manager-uid"},
    data: {requestId: "legacy-request"},
  });

  assert.deepEqual(managerChecks, ["manager-uid"]);
  assert.equal(randomByteRequest, 32);
  assert.equal(storageState.metadataCalls, 1);
  assert.equal(databaseState.updates.length, 1);
  const update = databaseState.updates[0];
  assert.equal(update.accessTokenHashes.operation, "arrayUnion");
  assert.match(update.accessTokenHashes.values[0], /^[a-f0-9]{64}$/);
  assert.equal(
      update.accessExpiresAt.toISOString(),
      "2026-08-26T09:00:00.000Z",
  );
  assert.equal(update.accessReissuedByUid, "manager-uid");
  const resultUrl = new URL(result.accessUrl);
  const rawToken = new URLSearchParams(resultUrl.hash.slice(1)).get("token");
  assert.match(rawToken, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(update.accessTokenHashes.values[0], hashAccessToken(rawToken));
  const persisted = JSON.stringify(update);
  assert.equal(persisted.includes(rawToken), false);
  assert.equal(persisted.includes(result.accessUrl), false);
  assert.equal(resultUrl.search, "");
  assert.equal(
      new URLSearchParams(resultUrl.hash.slice(1)).get("requestId"),
      "legacy-request",
  );
  assert.equal(resultUrl.searchParams.has("token"), false);
  assert.equal(JSON.stringify(logger.entries).includes(rawToken), false);
});

test("manager recovery rejects an old object after its seven-day retention", async () => {
  const {db, state: databaseState} = fakeDatabase({
    status: "sent",
    storageObject: OBJECT_NAME,
  });
  const {bucket} = fakeBucket({
    metadata: {
      timeCreated: new Date(
          NOW.getTime() - ACCESS_LIFETIME_MILLISECONDS - 1,
      ).toISOString(),
    },
  });
  const reissue = createManagerVideoAccessReissuer({
    db,
    bucket,
    publicBaseUrl: PUBLIC_BASE_URL,
    clock: () => NOW,
    assertManager: async () => {},
    arrayUnion: (value) => value,
  });

  await assert.rejects(
      () => reissue({auth: {uid: "manager"}, data: {requestId: "request-1"}}),
      (error) => error.code === "failed-precondition",
  );
  assert.equal(databaseState.updates.length, 0);
});

test("manager recovery does not restart retention after a legacy object restore", async () => {
  const {db, state: databaseState} = fakeDatabase({
    status: "sent",
    storageObject: OBJECT_NAME,
    createdAt: new Date("2026-08-17T09:00:00.000Z"),
  });
  // Cloud Storage gives a restored object a new creation time. The original
  // Firestore job time must still cap the legacy link's access lifetime.
  const {bucket} = fakeBucket({
    metadata: {timeCreated: "2026-08-20T08:30:00.000Z"},
  });
  const reissue = createManagerVideoAccessReissuer({
    db,
    bucket,
    publicBaseUrl: PUBLIC_BASE_URL,
    clock: () => NOW,
    assertManager: async () => {},
    arrayUnion: (value) => value,
    logger: quietLogger(),
  });

  const result = await reissue({
    auth: {uid: "manager"},
    data: {requestId: "restored-request"},
  });

  assert.equal(result.accessExpiresAt, "2026-08-24T09:00:00.000Z");
  assert.equal(
      databaseState.updates[0].accessExpiresAt.toISOString(),
      "2026-08-24T09:00:00.000Z",
  );
});

test("manager recovery rejects a restored legacy object after original expiry", async () => {
  const {db, state: databaseState} = fakeDatabase({
    status: "sent",
    storageObject: OBJECT_NAME,
    createdAt: new Date(
        NOW.getTime() - ACCESS_LIFETIME_MILLISECONDS - 1,
    ),
  });
  const {bucket} = fakeBucket({
    metadata: {timeCreated: "2026-08-20T08:30:00.000Z"},
  });
  const reissue = createManagerVideoAccessReissuer({
    db,
    bucket,
    publicBaseUrl: PUBLIC_BASE_URL,
    clock: () => NOW,
    assertManager: async () => {},
    arrayUnion: (value) => value,
    logger: quietLogger(),
  });

  await assert.rejects(
      () => reissue({
        auth: {uid: "manager"},
        data: {requestId: "restored-expired-request"},
      }),
      (error) => error.code === "failed-precondition",
  );
  assert.equal(databaseState.updates.length, 0);
});

test("manager recovery handles a missing Storage object cleanly", async () => {
  const {db, state: databaseState} = fakeDatabase({
    status: "sent",
    storageObject: OBJECT_NAME,
  });
  const missing = new Error("provider detail must not escape");
  missing.code = 404;
  const {bucket} = fakeBucket({metadataError: missing});
  const reissue = createManagerVideoAccessReissuer({
    db,
    bucket,
    publicBaseUrl: PUBLIC_BASE_URL,
    clock: () => NOW,
    assertManager: async () => {},
    arrayUnion: (value) => value,
  });

  await assert.rejects(
      () => reissue({auth: {uid: "manager"}, data: {requestId: "request-1"}}),
      (error) => error.code === "not-found" &&
        !String(error.message).includes("provider detail"),
  );
  assert.equal(databaseState.updates.length, 0);
});

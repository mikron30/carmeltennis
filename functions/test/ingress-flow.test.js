"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {getIngressSettings} = require("../src/video/config");
const {
  processEspVideoRequest,
  processManagerVideoRequest,
} = require("../src/video/ingress");
const {signEspPayload} = require("../src/video/signature");
const {USER_FIELDS} = require("../src/video/users");

function document(id, data) {
  return {id, data: () => data};
}

function fakeDatabase({reservations = [], users = []} = {}) {
  const writes = [];
  const db = {
    collection(name) {
      return {
        doc(id) {
          return {collectionName: name, id};
        },
        where() {
          return {get: async () => ({docs: reservations})};
        },
        async get() {
          return {docs: name === "users_2024" ? users : []};
        },
      };
    },
    async runTransaction(operation) {
      const transaction = {
        async get() {
          return {exists: false, data: () => ({})};
        },
        set(reference, value, options) {
          writes.push({reference, value, options});
        },
      };
      return operation(transaction);
    },
  };
  return {db, writes};
}

function queuedJob(writes) {
  return writes.find((write) =>
    write.reference.collectionName === "video_clip_requests",
  )?.value;
}

test("existing ESP32 request flow queues the exact pre-press forty seconds", async () => {
  const now = new Date("2026-08-17T18:06:17.000Z");
  const secret = "unit-test-device-secret-at-least-16";
  const unsigned = {
    courtNumber: 1,
    deviceId: "court-one-button",
    timestamp: Math.floor(now.getTime() / 1000),
    nonce: "unit_test_nonce_0001",
  };
  const payload = {...unsigned, signature: signEspPayload(unsigned, secret)};
  const {db, writes} = fakeDatabase({
    reservations: [document("reservation-1", {
      date: "2026-08-17",
      hour: 21,
      courtNumber: 1,
      userName: "Player One",
      partner: "Player Two",
    })],
    users: [
      document("player-1", {
        [USER_FIELDS.firstName]: "Player",
        [USER_FIELDS.lastName]: "One",
        [USER_FIELDS.email]: "one@example.com",
      }),
      document("player-2", {
        [USER_FIELDS.firstName]: "Player",
        [USER_FIELDS.lastName]: "Two",
        [USER_FIELDS.email]: "two@example.com",
      }),
    ],
  });
  const enqueued = [];

  const result = await processEspVideoRequest(payload, {
    db,
    deviceKeyConfiguration: JSON.stringify({
      "court-one-button": {secret, courts: [1]},
    }),
    now,
    ingressSettings: getIngressSettings({
      VIDEO_BUTTON_CLIP_DURATION_SECONDS: "40",
      VIDEO_CLIP_LEAD_SECONDS: "10",
    }),
    taskConfig: {},
    enqueue: async (task) => enqueued.push(task),
  });

  const job = queuedJob(writes);
  assert.equal(result.status, "queued");
  assert.equal(job.requestKind, "esp32");
  assert.equal(job.cameraChannel, 4);
  assert.equal(job.clipStart.toISOString(), "2026-08-17T18:05:37.000Z");
  assert.equal(job.clipEnd.toISOString(), "2026-08-17T18:06:17.000Z");
  assert.equal(job.reservation.slotDate, "2026-08-17");
  assert.equal(job.reservation.slotHour, 21);
  assert.equal(job.reservation.selectionSource, "current");
  assert.deepEqual(job.accessTokenHashes, []);
  assert.equal(job.accessExpiresAt, null);
  assert.equal(enqueued.length, 1);
  assert.equal(enqueued[0].requestId, result.requestId);
});

test("physical request extends the 21:00 reservation only until 22:30", async () => {
  // 19:15 UTC is 22:15 Israel summer time.
  const now = new Date("2026-08-17T19:15:00.000Z");
  const secret = "unit-test-device-secret-at-least-16";
  const unsigned = {
    courtNumber: 2,
    deviceId: "court-two-button",
    timestamp: Math.floor(now.getTime() / 1000),
    nonce: "unit_test_nonce_closing_0001",
  };
  const payload = {...unsigned, signature: signEspPayload(unsigned, secret)};
  const {db, writes} = fakeDatabase({
    reservations: [document("reservation-closing", {
      date: "2026-08-17",
      hour: 21,
      courtNumber: 2,
      userName: "Closing Player",
      partner: "Closing Partner",
    })],
    users: [
      document("closing-player", {
        [USER_FIELDS.firstName]: "Closing",
        [USER_FIELDS.lastName]: "Player",
        [USER_FIELDS.email]: "closing@example.com",
      }),
      document("closing-partner", {
        [USER_FIELDS.firstName]: "Closing",
        [USER_FIELDS.lastName]: "Partner",
        [USER_FIELDS.email]: "partner@example.com",
      }),
    ],
  });

  await processEspVideoRequest(payload, {
    db,
    deviceKeyConfiguration: JSON.stringify({
      "court-two-button": {secret, courts: [2]},
    }),
    now,
    ingressSettings: getIngressSettings({
      VIDEO_BUTTON_CLIP_DURATION_SECONDS: "40",
      VIDEO_CLIP_LEAD_SECONDS: "10",
    }),
    taskConfig: {},
    enqueue: async () => {},
  });

  const job = queuedJob(writes);
  assert.equal(job.clipStart.toISOString(), "2026-08-17T19:14:20.000Z");
  assert.equal(job.clipEnd.toISOString(), "2026-08-17T19:15:00.000Z");
  assert.equal(job.reservation.slotHour, 21);
  assert.equal(job.reservation.selectionSource, "closing_extension");
  assert.deepEqual(job.recipients.sort(), [
    "closing@example.com",
    "partner@example.com",
  ]);
});

test("existing manager request flow still queues the selected ten seconds", async () => {
  const {db, writes} = fakeDatabase();
  const managerChecks = [];
  const enqueued = [];

  const result = await processManagerVideoRequest({
    auth: {uid: "manager-uid"},
    data: {
      courtNumber: 2,
      date: "2026-08-17",
      time: "21:06:17",
      recipientEmail: "manager@example.com",
    },
  }, {
    db,
    now: new Date("2026-08-17T18:07:00.000Z"),
    ingressSettings: getIngressSettings({VIDEO_CLIP_LEAD_SECONDS: "10"}),
    taskConfig: {},
    assertManager: async (request) => managerChecks.push(request.auth.uid),
    enqueue: async (task) => enqueued.push(task),
  });

  const job = queuedJob(writes);
  assert.deepEqual(managerChecks, ["manager-uid"]);
  assert.equal(result.status, "queued");
  assert.equal(job.requestKind, "manager");
  assert.equal(job.cameraChannel, 6);
  assert.equal(job.clipStart.toISOString(), "2026-08-17T18:06:07.000Z");
  assert.equal(job.clipEnd.toISOString(), "2026-08-17T18:06:17.000Z");
  assert.deepEqual(job.recipients, ["manager@example.com"]);
  assert.equal(enqueued.length, 1);
});

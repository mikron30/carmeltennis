"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {enqueueVideoProcessing} = require("../src/video/tasks");

test("video task waits for the full processor timeout without changing clip time", async () => {
  let request;
  const client = {
    queuePath: (project, location, queue) =>
      `projects/${project}/locations/${location}/queues/${queue}`,
    taskPath: (project, location, queue, task) =>
      `projects/${project}/locations/${location}/queues/${queue}/tasks/${task}`,
    async createTask(value) {
      request = value;
    },
  };
  const now = new Date("2026-08-20T18:00:00.500Z");

  await enqueueVideoProcessing({
    requestId: "request-1",
    now,
    client,
    taskConfig: {
      projectId: "project-1",
      location: "europe-west3",
      queue: "video-clip-processor",
      processorUrl: "https://processor.example.invalid",
      serviceAccountEmail: "tasks@example.invalid",
      taskDelaySeconds: 15,
    },
  });

  assert.equal(request.task.dispatchDeadline.seconds, 930);
  assert.equal(request.task.scheduleTime.seconds, 1787248815);
  assert.deepEqual(
      JSON.parse(Buffer.from(request.task.httpRequest.body).toString("utf8")),
      {requestId: "request-1"},
  );
  assert.equal(
      request.task.httpRequest.url,
      "https://processor.example.invalid/tasks/process-video",
  );
});

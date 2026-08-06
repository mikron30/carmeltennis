"use strict";

const {CloudTasksClient} = require("@google-cloud/tasks");

const {VideoTaskEnqueueError} = require("./errors");

function taskIdForRequest(requestId) {
  return `video-${requestId}`;
}

function isAlreadyExists(error) {
  return error?.code === 6 || error?.code === "6" ||
    error?.code === "ALREADY_EXISTS";
}

/**
 * Cloud Tasks invokes a private processor with an OIDC identity.  The task
 * name is deterministic, so a retry after a Functions crash cannot enqueue a
 * second processor invocation for the same request.
 */
async function enqueueVideoProcessing({
  requestId,
  taskConfig,
  now = new Date(),
  client = new CloudTasksClient(),
}) {
  const parent = client.queuePath(
      taskConfig.projectId,
      taskConfig.location,
      taskConfig.queue,
  );
  const taskName = client.taskPath(
      taskConfig.projectId,
      taskConfig.location,
      taskConfig.queue,
      taskIdForRequest(requestId),
  );
  const body = Buffer.from(JSON.stringify({requestId}), "utf8");
  const task = {
    name: taskName,
    httpRequest: {
      httpMethod: "POST",
      url: `${taskConfig.processorUrl}/tasks/process-video`,
      headers: {"Content-Type": "application/json"},
      body,
      oidcToken: {
        serviceAccountEmail: taskConfig.serviceAccountEmail,
        audience: taskConfig.processorUrl,
      },
    },
    scheduleTime: {
      seconds: Math.floor(
          (now.getTime() + (taskConfig.taskDelaySeconds * 1000)) / 1000,
      ),
    },
  };

  try {
    await client.createTask({parent, task});
    return {taskName, alreadyQueued: false};
  } catch (error) {
    if (isAlreadyExists(error)) {
      return {taskName, alreadyQueued: true};
    }
    throw new VideoTaskEnqueueError("Unable to enqueue video processing", {
      cause: error,
    });
  }
}

module.exports = {
  enqueueVideoProcessing,
  isAlreadyExists,
  taskIdForRequest,
};

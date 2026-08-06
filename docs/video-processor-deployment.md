# Deploying the private video processor

This document is a deployment checklist, not a command to run blindly. The web
application may continue to be hosted from `build/web` on DigitalOcean; this
worker belongs in Google Cloud because it reads Firestore, Cloud Storage, Secret
Manager, and is called by Cloud Tasks.

## Required resources

- A private Cloud Storage bucket dedicated to video clips, with uniform
  bucket-level access and a lifecycle rule to delete clips after the agreed
  retention period (recommended: seven days).
- A Cloud Run service account dedicated to `video-processor`.
- A Cloud Tasks caller service account dedicated to the video queue.
- A Cloud Tasks queue named `video-clip-processor` in `europe-west3`.
- Secret Manager secrets for the NVR username/password and, when supported by
  the mail service, its bearer token.

Use the Firebase project `potent-howl-228108` explicitly for every Google Cloud
command. Do not copy an NVR host, username, password, signed URL, or service
account JSON key into this repository or a shell history file.

## IAM minimums

| Identity | Required access |
| --- | --- |
| Firebase Functions runtime account | `roles/cloudtasks.enqueuer` on the video queue |
| Cloud Tasks caller account | `roles/run.invoker` on this Cloud Run service only |
| Video processor account | Firestore job read/write, private video-bucket object read/write, access to its bound secrets, and permission to sign V4 URLs |

Deploy the service with unauthenticated access disabled. Cloud Tasks must attach
an OIDC token whose audience is the exact Cloud Run service URL. The endpoint
checks the Cloud Tasks task-name header as an additional guard.

Configure a Cloud Run startup/readiness probe for `GET /healthz`. It returns
503 when required secret or ordinary configuration is missing, preventing a
misconfigured revision from accepting queue traffic.

Deploy with Cloud Run request concurrency `1` and a request timeout of at least
900 seconds. FFmpeg is deliberately single-job per instance; set the service's
maximum instance count only after confirming that the NVR and outbound network
can safely handle parallel playback downloads.

## Environment and secrets

Use [`.env.example`](../services/video-processor/.env.example) only as a list of
variable names. Bind sensitive values with Cloud Run Secret Manager bindings,
for example conceptually:

```text
NVR_USERNAME <- projects/PROJECT/secrets/nvr-username:latest
NVR_PASSWORD <- projects/PROJECT/secrets/nvr-password:latest
MAIL_SERVICE_BEARER_TOKEN <- projects/PROJECT/secrets/mail-service-token:latest
```

Set ordinary configuration through deployment configuration, including:

```text
VIDEO_CLIP_BUCKET=…
NVR_BASE_URL=https://private-nvr.example:port
MAIL_SERVICE_URL=https://existing-mail-service.example/sendMail
COURT_CAMERA_MAP=1:4:Left Court,2:6:Right Court,3:7:Back Court
```

The default `NVR_TRACK_SUFFIX=1` produces Hikvision logical tracks 401, 601,
and 701. Verify actual firmware behavior before live use. `NVR_BASE_URL` rejects
plain HTTP unless `NVR_ALLOW_INSECURE_HTTP=true` is set deliberately. A public
HTTP NVR endpoint sends Digest credentials without transport confidentiality;
use a VPN/private tunnel or NVR HTTPS instead.

## Task producer contract

The Firebase Function should first create a `video_clip_requests` document with
`status: "queued"`, recipient email addresses, court number, mapped channel,
and server-generated `clipStart`/`clipEnd` timestamps. Then it creates a task:

```json
{
  "httpMethod": "POST",
  "url": "https://VIDEO_PROCESSOR_URL/tasks/process-video",
  "oidcToken": {"serviceAccountEmail": "TASK_CALLER_SERVICE_ACCOUNT"},
  "body": {"requestId": "FIRESTORE_DOCUMENT_ID"}
}
```

Use the same deterministic request ID for the Firestore document and Cloud Task
deduplication. Delay the task about 10–15 seconds after the press so the NVR has
time to finalize the recording. The worker returns 503 for retryable upstream
errors; configure Cloud Tasks retry/backoff and a dead-letter alert.

## Before the first live request

1. Create a manual manager test request for each court and confirm the worker
   finds channels 4, 6, and 7.
2. Check that the resulting MP4 opens in Chrome/Safari and contains exactly the
   requested pre-press interval.
3. Confirm that only the two intended mail recipients receive a link, and that
   the link expires as configured.
4. Confirm no signed URL appears in Cloud Run logs or the Firestore document.
5. Trigger a temporary NVR/mail failure and verify `queued` retry behavior and
   final `failed` job state after the retry budget.

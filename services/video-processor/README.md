# Carmel Tennis video processor

This is a private Cloud Run worker. It processes one trusted Firestore job at a
time; it is not a public API and it never exposes NVR credentials to Flutter or
an ESP32.

The Firebase Functions producer enqueues an OIDC-authenticated Cloud Task:

```json
POST /tasks/process-video
{"requestId":"<video_clip_requests document ID>"}
```

Cloud Run IAM is the authentication boundary. Give `roles/run.invoker` only to
the Cloud Tasks caller service account and deploy with `--no-allow-unauthenticated`.
The endpoint additionally requires `X-CloudTasks-TaskName` by default.

## Expected Firestore document

The Functions producer creates a document in `video_clip_requests` before it
enqueues the task. The processor accepts both ESP32 and manager-test requests;
manager requests supply the recipients directly after the Function authorizes
the manager.

```json
{
  "status": "queued",
  "requestKind": "esp32",
  "courtNumber": 1,
  "cameraChannel": 4,
  "pressedAt": "Firestore Timestamp",
  "clipStart": "Firestore Timestamp",
  "clipEnd": "Firestore Timestamp",
  "recipients": ["player@example.com", "partner@example.com"],
  "attempts": 0
}
```

`clipStart` and `clipEnd` are authoritative timestamps produced by the server.
New physical-button jobs request 40 seconds and manager jobs request 10
seconds. The worker falls back to a ten-second `clipStart` only for an older
job shape that omitted the explicit start.
It validates the configured court-to-camera mapping rather than trusting the
document's camera channel.

State transitions are `queued → processing → sent`; a non-retryable problem is
recorded as `failed`. Transient NVR, Storage, and mail errors return the job to
`queued` and return HTTP 503 so Cloud Tasks retries. The request document stores
object metadata and `linkExpiresAt`. The direct V4 Storage URL is kept only in
memory long enough to send the email; it is never stored in Firestore or written
to application logs.

## Local setup and tests

Use Python 3.12 and a local `.env` only for disposable development values:

```powershell
cd services/video-processor
python -m unittest discover -s tests -v
docker build -t carmel-video-processor .
```

The container needs Application Default Credentials in development. Production
uses its Cloud Run service account; do not mount or commit a service-account
JSON key.

## Hikvision assumptions to verify

The adapter uses Digest-authenticated ISAPI `ContentMgmt/search` then
`ContentMgmt/download`, with logical main-stream tracks `401`, `601`, and `701`
for NVR channels 4, 6, and 7. Firmware can differ. Before enabling live button
traffic, run a redacted capability probe against the actual NVR and confirm:

- `search` returns a playback URI for each mapped channel;
- `download` accepts that URI and returns video bytes;
- NVR time zone is `Asia/Jerusalem` and recording timestamps agree with it;
- the NVR is reachable through HTTPS or a private VPN/tunnel.

Do not set `NVR_ALLOW_INSECURE_HTTP=true` for Internet-routed production traffic.
If a temporary legacy NVR setup requires it, restrict it with static egress and
NVR firewall allowlisting, then replace it with HTTPS/private connectivity.

## Mail service contract

The adapter preserves the existing service contract:

```json
{"to":"player@example.com", "subject":"…", "html":"…"}
```

It sends only the registered/supplied players, never the legacy administrator
fallback recipient. It uses correct UTF-8 Hebrew subjects and content. It also
sends an `X-Idempotency-Key` header. When the existing mail-service source is
available, it should authenticate the caller and persist that header before
delivery to make crashes between delivery and Firestore acknowledgement safe.

## Security constraints

- Bind `NVR_USERNAME`, `NVR_PASSWORD`, and optionally
  `MAIL_SERVICE_BEARER_TOKEN` from Secret Manager to Cloud Run environment
  variables. Do not use `.env` or `gcloud --set-env-vars` for secrets.
- Keep the clip bucket private with uniform bucket-level access. The worker
  emails a direct V4 signed Storage URL whose expiry is capped at seven days
  from the object's creation time.
- The worker service account needs Firestore access, write/read access only to
  the dedicated video bucket, Secret Manager accessor for bound secrets, and
  `roles/iam.serviceAccountTokenCreator` on itself for keyless URL signing.
- Apply [`storage-lifecycle.json`](storage-lifecycle.json) to the dedicated
  bucket so live MP4 clips are deleted after seven days. Lifecycle processing is
  asynchronous, and the bucket's separate soft-delete policy controls the
  recovery window after deletion. This service intentionally does not delete
  user data on its own.

# Video-button setup

This is the deployment handoff for the new video path. It does **not** change
the existing manual `build/web` publishing flow to DigitalOcean: the web app
remains a static client there. The Firebase Functions and private Cloud Run
processor must be deployed separately to `potent-howl-228108`.

No command below should be run until the NVR and mail-service details have
been checked. Never place NVR credentials, ESP32 keys, mail credentials,
service-account JSON, or signed download URLs in this repository.

## What is deployed

- `requestVideoClip`: public Firebase HTTPS endpoint for an ESP32. It accepts
  only a signed JSON POST, uses the server's current Israel time for the
  reservation and clip window, then queues a job.
- `requestVideoClipForManager`: authenticated Firebase callable used by the
  web-only manager menu. It queues the same processing pipeline from court,
  Israel date/time, and one recipient email; it deliberately does not need an
  ESP32 or a reservation.
- `services/video-processor`: a private Cloud Run worker. It retrieves the
  Hikvision recording, creates an H.264/AAC MP4, stores it privately, creates
  a temporary URL, and calls the existing mail-service contract.

The web menu is a convenience only. The callable verifies manager status on
the server from `users_2024` before creating a manual request.

## Required Google Cloud configuration

1. Provision the private Cloud Run service, Cloud Tasks queue
   `video-clip-processor` in `europe-west3`, and a dedicated private Cloud
   Storage video bucket. Follow [the processor deployment checklist](video-processor-deployment.md)
   for IAM, the NVR, FFmpeg, signed URLs, and the mail adapter.
2. Deploy Cloud Run with unauthenticated access disabled. Grant its
   `run.invoker` role only to the Cloud Tasks caller service account.
3. Grant the Firebase Functions runtime identity permission to enqueue tasks
   in that queue and permission to create tasks using the Cloud Tasks caller
   identity. Use the exact deployed service identities rather than assuming a
   legacy App Engine account.
4. Create a Firebase Functions secret interactively (the value is never put in
   an `.env` file):

   ```powershell
   firebase functions:secrets:set ESP32_VIDEO_DEVICE_KEYS --project potent-howl-228108
   ```

   Enter JSON keyed by physical device ID. For example, with placeholder
   values only:

   ```json
   {
     "court-1-button": {"secret": "replace-with-a-random-secret-of-at-least-16-characters", "courts": [1]},
     "court-2-button": {"secret": "replace-with-a-different-random-secret", "courts": [2]},
     "court-3-button": {"secret": "replace-with-a-different-random-secret", "courts": [3]}
   }
   ```

   Keep each secret in the matching ESP32's protected storage and do not reuse
   it for another court.
5. Copy [the Functions template](../functions/.env.example) to the ignored
   project-specific file `functions/.env.potent-howl-228108`, then replace the
   Cloud Run URL and task-caller service-account email. These are deployment
   settings, not secrets. The Firebase CLI reads this project-specific file at
   deployment time.
6. Deploy just the two new Functions, explicitly selecting the production
   project:

   ```powershell
   firebase deploy --only functions:requestVideoClip,functions:requestVideoClipForManager --project potent-howl-228108
   ```

The processor's `NVR_BASE_URL`, `NVR_USERNAME`, `NVR_PASSWORD`, and optional
mail bearer token belong in Cloud Run configuration/Secret Manager bindings,
not the Functions environment. The provided NVR's Internet-routed HTTP port
should only be used after an explicit risk decision; HTTPS or private
connectivity is the intended production configuration.

## ESP32 protocol (for the later button rollout)

Send `POST` with `Content-Type: application/json` to the deployed
`requestVideoClip` URL:

```json
{
  "courtNumber": 1,
  "deviceId": "court-1-button",
  "timestamp": 1730000000,
  "nonce": "a-new-base64url-nonce-for-every-press",
  "signature": "lowercase-hex-hmac-sha256"
}
```

`signature` is HMAC-SHA-256 of this exact UTF-8 canonical string, using that
device's secret:

```text
v1\n<deviceId>\n<courtNumber>\n<timestamp>\n<nonce>
```

The endpoint accepts only a fresh timestamp, verifies the HMAC before reading
Firestore, uses its own current Israel time, deduplicates the nonce, and rate
limits each court. The server, not the ESP32 clock, selects the reservation
and ten-second video interval.

## First test

1. Sign in to the web app as an existing manager.
2. Open the side menu and select `שליחת וידאו ידנית`.
3. Choose court, Israel-local date/time, and a recipient email. This creates a
   `video_clip_requests` job without needing the ESP32 or a reservation.
4. Follow its state: `queued`, `processing`, `sent`, or `failed`. Do not put a
   signed URL into Firestore; only object metadata and expiry information are
   stored.
5. After the existing mail-service source is available, add authentication and
   durable idempotency handling for its `X-Idempotency-Key` header before
   relying on retry behaviour for production delivery.

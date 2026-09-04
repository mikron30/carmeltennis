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
- `openVideoClip`: public token resolver retained for manager-regenerated and
  previously issued stable links. Normal new video emails bypass it.
- `regenerateVideoClipAccessForManager`: authenticated manager callable that
  creates another link for an existing live MP4 without contacting the NVR.
- `services/video-processor`: a private Cloud Run worker. It retrieves the
  Hikvision recording, creates an H.264/AAC MP4, stores it privately, creates a
  direct V4 signed download URL, and calls the existing mail-service contract.

The web menu is a convenience only. The callable verifies manager status on
the server from `users_2024` before creating a manual request.

## Required Google Cloud configuration

1. Provision the private Cloud Run service, Cloud Tasks queue
   `video-clip-processor` in `europe-west3`, and a dedicated private Cloud
   Storage video bucket. Follow [the processor deployment checklist](video-processor-deployment.md)
   for IAM, the NVR, FFmpeg, private access links, and the mail adapter.
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
5. Create the dedicated `video-access-runtime` service account and grant only
   the Firestore, private-object read, and self-signing permissions listed in
   [the processor deployment checklist](video-processor-deployment.md). It must
   not receive NVR secrets or video-object write permission.
6. Copy [the Functions template](../functions/.env.example) to the ignored
   project-specific file `functions/.env.potent-howl-228108`, then replace the
   Cloud Run URL and task-caller service-account email. Set the video bucket,
   public `openVideoClip` URL, seven-day access lifetime, and 15-minute signed
   URL lifetime exactly as shown in the template. These are deployment settings,
   not secrets. The Firebase CLI reads this project-specific file at deployment
   time. The obsolete `VIDEO_BUTTON_CLIP_START_OFFSET_SECONDS` and
   `VIDEO_BUTTON_CLIP_END_OFFSET_SECONDS` settings may be removed; current code
   ignores them. Set `VIDEO_BUTTON_CLIP_DURATION_SECONDS=40` for physical
   buttons and keep `VIDEO_CLIP_LEAD_SECONDS=10` for manager-selected clips.
7. Deploy the four video Functions, explicitly selecting the production
   project. Clear any inherited `DEBUG` value first because Firebase CLI debug
   output can include credential-bearing legacy Runtime Config responses:

   ```powershell
   Remove-Item Env:DEBUG -ErrorAction SilentlyContinue
   firebase deploy --only functions:openVideoClip,functions:regenerateVideoClipAccessForManager,functions:requestVideoClip,functions:requestVideoClipForManager --project potent-howl-228108
   ```

   Do not use `firebase --debug` while legacy Runtime Config values remain.

The processor's `NVR_BASE_URL`, `NVR_USERNAME`, `NVR_PASSWORD`, and optional
mail bearer token belong in Cloud Run configuration/Secret Manager bindings,
not the Functions environment. The provided NVR's Internet-routed HTTP port
should only be used after an explicit risk decision; HTTPS or private
connectivity is the intended production configuration.

## ESP32 protocol (for the later button rollout)

Ready-to-flash Arduino firmware, secure provisioning, wiring, and test
instructions are in
[`firmware/esp32_video_button`](../firmware/esp32_video_button/README.md).

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
limits each court. The server, not the ESP32 clock, selects the physical
button's forty-second interval immediately before the press. Reservation
selection tries the current hour, then the previous hour, then the next hour,
within the 07:00-22:00 booking grid. The 21:00 reservation remains valid from
22:00 through 22:29:59; presses at 22:30 or later are rejected. A clip crossing
an hour is allowed only when the selected previous/closing reservation owns
that earlier footage; a current or next reservation remains protected from
footage belonging to different players.

## First test

1. Sign in to the web app as an existing manager.
2. Open the side menu and select `שליחת וידאו ידנית`.
3. Choose court, Israel-local date/time, and a recipient email. This creates a
   `video_clip_requests` job without needing the ESP32 or a reservation.
4. Follow its state: `queued`, `processing`, `sent`, or `failed`. Firestore may
   contain `linkExpiresAt`, but never the direct signed Storage URL.
5. After the existing mail-service source is available, add authentication and
   durable idempotency handling for its `X-Idempotency-Key` header before
   relying on retry behaviour for production delivery.

## Manager recovery for an existing MP4

An authenticated manager client can invoke the callable without creating a new
video job:

```dart
final callable = FirebaseFunctions.instanceFor(region: 'europe-west3')
    .httpsCallable('regenerateVideoClipAccessForManager');
final result = await callable.call(<String, dynamic>{
  'requestId': '<video_clip_requests document id>',
});
final accessUrl = (result.data as Map)['accessUrl'] as String;
```

The callable checks manager authorization, the Firestore job, the seven-day
expiry, and the live Storage object. It appends only a token hash and returns a
new link that the manager can copy or forward. It does not enqueue a task or
read the NVR. Existing direct-GCS emails cannot change in place.

If an object was deleted by the former two-day lifecycle rule but is still in
the bucket's soft-delete recovery window, restore only its exact generation
before calling the helper. First apply and verify the seven-day rule; lifecycle
changes can take up to 24 hours to propagate and the former rule may still act
during that window.

```powershell
gcloud.cmd storage ls --soft-deleted --long `
  "gs://potent-howl-228108-video-clips/<storageObject>" `
  --project=potent-howl-228108
gcloud.cmd storage restore `
  "gs://potent-howl-228108-video-clips/<storageObject>#<generation>" `
  --project=potent-howl-228108
```

Never bulk-restore clips, and do not reprocess the NVR when the correct object
can be restored.

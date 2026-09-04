# Deploying the private video processor

This document is a deployment checklist, not a command to run blindly. The web
application may continue to be hosted from `build/web` on DigitalOcean; this
worker belongs in Google Cloud because it reads Firestore, Cloud Storage, Secret
Manager, and is called by Cloud Tasks.

## Required resources

- A private Cloud Storage bucket dedicated to video clips, with uniform
  bucket-level access and the checked-in lifecycle rule that deletes live MP4
  clips after seven days.
- A Cloud Run service account dedicated to `video-processor`.
- A Cloud Tasks caller service account dedicated to the video queue.
- A Cloud Tasks queue named `video-clip-processor` in `europe-west3`.
- Secret Manager secrets for the NVR username/password and, when supported by
  the mail service, its bearer token.

Use the Firebase project `potent-howl-228108` explicitly for every Google Cloud
command. Do not copy an NVR host, username, password, signed URL, or service
account JSON key into this repository or a shell history file.

Apply and verify the video-retention rule from the repository root:

```powershell
gcloud.cmd storage buckets update gs://potent-howl-228108-video-clips `
  --lifecycle-file=services/video-processor/storage-lifecycle.json `
  --project=potent-howl-228108
gcloud.cmd storage buckets describe gs://potent-howl-228108-video-clips `
  --format="json(lifecycle_config,soft_delete_policy)" `
  --project=potent-howl-228108
```

The lifecycle action is asynchronous: a matching object becomes eligible at
age seven days and may remain visible briefly while Cloud Storage processes the
action. The bucket's seven-day soft-delete policy keeps a deleted clip
recoverable during that additional safety window. A lifecycle configuration
change can take up to 24 hours to propagate, and the former two-day rule may
still act during that window. Apply and verify the seven-day rule before
restoring a legacy soft-deleted clip.

## IAM minimums

| Identity | Required access |
| --- | --- |
| Firebase Functions runtime account | `roles/cloudtasks.enqueuer` on the video queue |
| Cloud Tasks caller account | `roles/run.invoker` on this Cloud Run service only |
| Video processor account | Firestore job read/write, private video-bucket object read/write, access to its bound secrets, and `roles/iam.serviceAccountTokenCreator` on itself |
| Video access account | `roles/datastore.user`, bucket-scoped `roles/storage.objectViewer`, and `roles/iam.serviceAccountTokenCreator` on itself |

Create the least-privilege access identity before deploying the two access
Functions. The deployer also needs `roles/iam.serviceAccountUser` on it:

```powershell
$accessSa = "video-access-runtime@potent-howl-228108.iam.gserviceaccount.com"
gcloud.cmd services enable iamcredentials.googleapis.com `
  --project=potent-howl-228108
gcloud.cmd iam service-accounts create video-access-runtime `
  --display-name="Carmel Tennis video access" `
  --project=potent-howl-228108
gcloud.cmd projects add-iam-policy-binding potent-howl-228108 `
  --member="serviceAccount:$accessSa" `
  --role=roles/datastore.user
gcloud.cmd storage buckets add-iam-policy-binding `
  gs://potent-howl-228108-video-clips `
  --member="serviceAccount:$accessSa" `
  --role=roles/storage.objectViewer `
  --project=potent-howl-228108
gcloud.cmd iam service-accounts add-iam-policy-binding $accessSa `
  --member="serviceAccount:$accessSa" `
  --role=roles/iam.serviceAccountTokenCreator `
  --project=potent-howl-228108
$deployerAccount = (gcloud.cmd config get-value account).Trim()
gcloud.cmd iam service-accounts add-iam-policy-binding $accessSa `
  --member="user:$deployerAccount" `
  --role=roles/iam.serviceAccountUser `
  --project=potent-howl-228108
```

If the service account already exists, skip only its `create` command. Grant
the actual deployment service account instead when deployment is automated.
Do not grant the access identity Storage write, Cloud Tasks, NVR, or Secret
Manager access.

The processor signs direct private download URLs without a downloaded key.
Grant its runtime identity permission to call `signBlob` on itself:

```powershell
$processorSa = "video-processor-runtime@potent-howl-228108.iam.gserviceaccount.com"
gcloud.cmd iam service-accounts add-iam-policy-binding $processorSa `
  --member="serviceAccount:$processorSa" `
  --role=roles/iam.serviceAccountTokenCreator `
  --project=potent-howl-228108
```

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
SIGNED_URL_TTL_SECONDS=604800
SIGNED_URL_SERVICE_ACCOUNT_EMAIL=video-processor-runtime@PROJECT.iam.gserviceaccount.com
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
errors; configure Cloud Tasks retry/backoff and a dead-letter alert. The task's
930-second dispatch deadline is deliberately slightly longer than the worker's
900-second request timeout, so a long FFmpeg invocation is not retried while it
is still running.

The delay does not move the requested footage. Physical jobs store
`clipStart = pressedAt - 40 seconds`; manager jobs remain
`clipStart = pressedAt - 10 seconds`. Both store `clipEnd = pressedAt`. The
worker passes those timestamps unchanged to Hikvision and FFmpeg, which seeks
within the larger recording segment and requests the exact output duration.

Keep queue throughput aligned with the processor's `concurrency=1` and
`max-instances=3`, and use a backoff long enough for the NVR recording to become
available:

```powershell
gcloud.cmd tasks queues update video-clip-processor `
  --location=europe-west3 `
  --project=potent-howl-228108 `
  --max-concurrent-dispatches=3 `
  --max-dispatches-per-second=1 `
  --max-attempts=100 `
  --max-retry-duration=0s `
  --min-backoff=30s `
  --max-backoff=600s `
  --max-doublings=4
```

The worker independently permits at most five claimed processing attempts. The
queue retains a larger delivery budget because IAM, platform, startup, or
deadline failures can consume a Cloud Tasks attempt before the worker claims
the Firestore job. After five claimed retryable failures, the next delivery
marks the job `attempts_exhausted` and acknowledges the task.

## Production deployment order

Always name `potent-howl-228108` explicitly.
Before running Firebase CLI commands, clear any inherited `DEBUG` variable.
Firebase debug output can include legacy Runtime Config response bodies, which
may contain credentials:

```powershell
Remove-Item Env:DEBUG -ErrorAction SilentlyContinue
```

Do not use `firebase --debug` while legacy Runtime Config values still exist.

1. Apply the seven-day lifecycle rule with the command near the top of this
   document.
2. Create/grant the access service account and deploy the Functions when the
   optional manager link-regeneration endpoint is needed:

   ```powershell
   firebase deploy --only functions:openVideoClip,functions:regenerateVideoClipAccessForManager,functions:requestVideoClip,functions:requestVideoClipForManager --project potent-howl-228108
   ```

3. Restore the processor's self-`TokenCreator` grant shown above, then build
   and deploy the private processor with direct signed links configured:

   ```powershell
   $image = "europe-west3-docker.pkg.dev/potent-howl-228108/cloud-run-source-deploy/video-processor:direct-signed-v1"
   gcloud.cmd builds submit services/video-processor `
     --tag=$image `
     --project=potent-howl-228108
   gcloud.cmd run deploy video-processor `
     --image=$image `
     --region=europe-west3 `
     --project=potent-howl-228108 `
     --no-allow-unauthenticated `
     --service-account=video-processor-runtime@potent-howl-228108.iam.gserviceaccount.com `
     --cpu=1 --memory=4Gi --concurrency=1 --timeout=900 --max-instances=3 `
     --startup-probe="httpGet.path=/healthz,httpGet.port=8080,initialDelaySeconds=0,timeoutSeconds=5,periodSeconds=10,failureThreshold=6" `
     --update-env-vars="SIGNED_URL_TTL_SECONDS=604800,SIGNED_URL_SERVICE_ACCOUNT_EMAIL=video-processor-runtime@potent-howl-228108.iam.gserviceaccount.com" `
     --remove-env-vars="VIDEO_PUBLIC_BASE_URL,VIDEO_ACCESS_TTL_SECONDS"
   ```

4. Keep the processor's self-`TokenCreator` grant and existing Storage/secret
   bindings. Never grant it a downloadable service-account key.

## Before the first live request

1. Create a manual manager test request for each court and confirm the worker
   finds channels 4, 6, and 7.
2. Check that the resulting MP4 opens in Chrome/Safari and contains exactly the
   requested pre-press interval.
3. Confirm that only the two intended mail recipients receive a direct private
   Storage link and that it downloads the MP4.
4. Confirm Firestore contains only `linkExpiresAt` and object metadata, and
   that the signed URL appears in neither application logs nor Firestore.
5. Trigger a temporary NVR/mail failure and verify `queued` retry behavior and
   final `failed` job state after the retry budget.

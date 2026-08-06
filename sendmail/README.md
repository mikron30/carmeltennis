# Carmel Tennis mail service

This Cloud Run service preserves the existing `POST /sendMail` contract:

```json
{"to":"member@example.com","subject":"Subject","html":"<p>Message</p>"}
```

## Configuration

`SMTP_PASSWORD` is a secret. Create a Secret Manager secret such as
`smtp-password`, bind it to the Cloud Run environment variable
`SMTP_PASSWORD`, and grant the mail-service runtime account Secret Manager
Secret Accessor. Set `SMTP_USER` and the optional SMTP host/port settings as
ordinary Cloud Run environment variables. Do not put a Gmail app password in
source control, `.env`, Docker build arguments, or Flutter.

The existing web client calls this service directly, so keep its current
public access until that client has been migrated to an authenticated server
path. The video processor calls the same endpoint via its `MAIL_SERVICE_URL`.

## Video credentials are not mail credentials

The Hikvision username and password belong only to the **video-processor**
Cloud Run service, bound from Secret Manager as `NVR_USERNAME` and
`NVR_PASSWORD`. Never put them in this service, Firebase Functions, Flutter,
or an ESP32.

The ESP32 uses a third, unrelated secret: `ESP32_VIDEO_DEVICE_KEYS` in Firebase
Functions Secret Manager.

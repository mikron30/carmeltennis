# Manual video download from my reservations

This utility lets an authorized Carmel Tennis user choose one of their own
reservations and download the matching Hikvision recording.

It signs in to Firebase with the same email/password used by the app, reads
`users_2024` and `reservations`, then downloads the selected court/hour from
the NVR.

## Install

```powershell
py -m pip install -r requirements-video-download.txt
```

Install FFmpeg separately and make sure `ffmpeg` is in `PATH`.

## Firebase login

No service-account JSON, ADC, or `gcloud auth application-default login` is
required.

On the first run, enter the Carmel Tennis account email. The script saves only
that email in:

```text
%USERPROFILE%\.carmeltennis_video.json
```

On later runs the saved email is used automatically.

The Carmel Tennis password is requested once and then stored securely in Windows Credential Manager. The NVR password is handled the same way after the first successful NVR connection.

## NVR settings

Set the same values used by the video processor:

```powershell
$env:NVR_BASE_URL="http://109.67.172.30:8080"
$env:NVR_USERNAME="admin"
# NVR_PASSWORD is optional; if omitted, it is requested once and saved securely.
$env:NVR_TIME_ZONE="Asia/Jerusalem"
$env:COURT_CAMERA_MAP="1:4:Left Court,2:6:Right Court,3:7:Back Court"
```

If the NVR returns Israel wall-clock timestamps with a literal `Z`, also set:

```powershell
$env:NVR_SEARCH_RESULTS_ARE_LOCAL_TIME="true"
```

## Run

```powershell
py tools\download_my_tennis_video.py
```

By default the script shows reservations from **today and yesterday only**.

For one exact date:

```powershell
py tools\download_my_tennis_video.py --date 2026-09-27
```

For older recordings:

```powershell
py tools\download_my_tennis_video.py --days-back 120
```

The output is written to `downloaded_tennis_videos`.

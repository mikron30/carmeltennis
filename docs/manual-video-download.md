# Manual video download from my reservations

This utility is intended for an authorized club operator who already has
Firestore and NVR access.

It resolves a player from `users_2024`, lists only reservations where that
player appears as `userName` or `partner`, lets the operator choose a slot,
then downloads the matching Hikvision recording for the mapped court.

## Install

```powershell
py -m pip install -r requirements-video-download.txt
```

Install FFmpeg separately and make sure both `ffmpeg` and `ffprobe` are in
`PATH`.

## Firebase authentication

Use either a service-account file:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\service-account.json"
```

or Application Default Credentials.

Never commit the service-account JSON.

## NVR settings

Set the same values used by the video processor:

```powershell
$env:NVR_BASE_URL="https://nvr-host:port"
$env:NVR_USERNAME="..."
$env:NVR_PASSWORD="..."
$env:NVR_TIME_ZONE="Asia/Jerusalem"
$env:COURT_CAMERA_MAP="1:4:Left Court,2:6:Right Court,3:7:Back Court"
```

If the specific NVR returns Israel wall-clock timestamps with a literal `Z`,
also set:

```powershell
$env:NVR_SEARCH_RESULTS_ARE_LOCAL_TIME="true"
```

## Run

```powershell
py tools\download_my_tennis_video.py --email "your-account@example.com"
```

By default the script shows matching reservations from the last 30 days and
the next 7 days. For one exact date:

```powershell
py tools\download_my_tennis_video.py --email "your-account@example.com" --date 2026-09-27
```

For older recordings:

```powershell
py tools\download_my_tennis_video.py --email "your-account@example.com" --days-back 120
```

The output is written to `downloaded_tennis_videos`.

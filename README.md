# LEETO

A Flutter-based LeetCode team-tracking app with teammate activity, progress insights, and push notifications for new Accepted submissions.

## Features

- Track your primary LeetCode profile and teammates.
- View team leaderboard and problem-solving statistics.
- Explore LeetCode-style contribution heatmaps.
- Follow recent team submissions and activity.
- Receive push notifications when a tracked teammate submits an Accepted solution.
- Prevent duplicate notifications through backend deduplication.

## Project Structure

```text
leettrack/
├── leettrack-main/
    └── Flutter application

 backend/
    └── leeto-push-notifications/
        └── Node.js / TypeScript notification service
```

## Technology Stack

| Area | Technology |
|---|---|
| Mobile app | Flutter, Dart |
| Authentication and data | Firebase Authentication, Cloud Firestore |
| Push notifications | Firebase Cloud Messaging (FCM) |
| Backend | Node.js, TypeScript, Express |
| LeetCode data | LeetCode public GraphQL endpoint |
| Hosting | Render Web Service |
| Scheduled polling | cron-job.org |
| Source control | Git, GitHub |

## Backend

The backend polls tracked LeetCode usernames for recent Accepted submissions and sends FCM notifications to LEETO users who track those profiles.

- Reads tracked usernames and FCM tokens from Firestore.
- Polls each distinct username once per cycle.
- Sends notifications only for Accepted submissions.
- Uses Firestore-based deduplication to avoid duplicate notifications.
- Provides a health-check endpoint and a protected polling endpoint.

**Backend repository:** [leeto-push-notifications](https://github.com/Harshitverma677/leeto-push-notifications)

## Backend API

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/health` | Check backend availability |
| POST | `/internal/run-poll` | Run one polling cycle; requires a Bearer token |

## Environment Configuration

Configure backend secrets in the hosting provider's environment settings. Do not commit service-account JSON files or `.env` files.

Required backend variables include:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_JSON` (or a local service-account file path for development)
- `POLL_SECRET`
- `POLL_MAX_CONCURRENCY`
- `MAX_SUBMISSION_LOOKBACK`
- `NODE_ENV`

Use `eeto-push-notifications/.env.example` as the local configuration reference.

## Run Locally

### Flutter app

Run from the Flutter project directory:

```bash
cd leettrack-main
flutter pub get
flutter run
```

### Backend

Run from the backend repo by cloning it :

```bash
cd eeto-push-notifications
npm install
cp .env.example .env
```

Fill in the required values in `.env`, then run:

```bash
npm run check
npm test
npm run dev
```

Health check: `GET http://localhost:3000/health`

## Deployment

- Deploy the backend directory as a Render Web Service.
- Build command: `npm install --include=dev && npm run build`
- Start command: `npm start`
- Configure secrets as Render environment variables.
- Configure cron-job.org to call `POST /internal/run-poll` on the desired schedule with the `Authorization: Bearer <POLL_SECRET>` header.

## Security

- Never commit Firebase Admin service-account credentials.
- Never commit `.env` files or expose `POLL_SECRET`.
- Keep FCM server credentials on the backend only.

# LEETO — App Overview and Technology Stack

## 1. Project Overview

**LEETO** is a Flutter-based LeetCode team-tracking app that brings a user's own coding progress and teammates' public LeetCode activity into one dashboard. It is designed for students, coding partners, and interview-preparation groups who want to compare problem-solving progress and monitor recent submissions.

The app uses a dark, coding-focused interface with a leaderboard, profile statistics, a LeetCode-style contribution heatmap, and a recent team activity feed.

**Data-integrity rule:** LEETO should display real data returned by LeetCode's public GraphQL endpoint. If a field is unavailable or a request fails, the app should show an honest unavailable/error state rather than inventing statistics.

## 2. Main Features

### Primary LeetCode profile
- On first launch, the user enters their public LeetCode username.
- The app verifies the profile through the available public GraphQL interface.
- The username is saved locally so the app can open directly on later launches.
- The primary profile is marked **You** or **Primary Profile** in the leaderboard.
- Sign Out clears the local primary-profile selection and returns to username setup. It does not sign the user out of LeetCode itself.

### Teammate management
- Add teammates using public LeetCode usernames.
- Validate usernames against available public profile data.
- Save the teammate roster locally on the device.
- Open each teammate's profile to inspect available statistics and submissions.
- Remove a single teammate with confirmation.
- Wipe all teammate profiles with confirmation while preserving the primary profile.
- Avoid duplicate entries if the primary username is also entered as a teammate.

### Leaderboard
- Show the primary profile and teammates together.
- Display available public statistics such as total solved problems and difficulty breakdowns.
- Support search and applicable sorting/filtering.
- Identify the primary user clearly.
- Use actual fetched values. Do not fabricate missing statistics.

### LeetCode-style contribution heatmap
- Show daily activity in a calendar grid with seven weekday rows.
- Use one cell for each actual calendar date, with green intensity levels representing real submission counts.
- Separate month groups visually and align month labels with the calendar.
- Support horizontal scrolling across approximately the past year while keeping the profile screen vertically scrollable.
- Show totals, active days, and maximum streak only when they can be calculated correctly from complete data.
- Handle month lengths, leap years, loading, errors, and unavailable data.

### Live Team Activity
- Show recent public submissions from the rolling past seven days, when available.
- Group submissions under date headings such as Today, Yesterday, or a calendar date.
- Display each submission as a separate item with teammate username, problem title, difficulty, time, and status only when the API provides those fields.
- Sort newest first.
- Do not claim guaranteed instant updates. Public data availability and refresh frequency limit how current the feed can be.

### Profile and local controls
- Show the primary profile and its contribution heatmap.
- Provide a confirmed action to remove all teammates without deleting the primary profile.
- Provide Sign Out for the local primary-profile selection.
- Do not include an app login/password system or backend account system.

## 3. Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Mobile UI | **Flutter** | Cross-platform mobile UI and layout |
| Programming language | **Dart** | App logic, models, services, and widgets |
| Data source | **LeetCode public GraphQL API** | Retrieve available public profile statistics, calendar activity, and recent submissions |
| Network requests | Dart HTTP client, such as `http` or `dio` | Send GraphQL requests and handle responses |
| Local persistence | `shared_preferences` or another small on-device store | Persist primary username, teammate roster, and local preferences |
| UI components | Flutter widgets | Dashboard, leaderboard, profile cards, dialogs, heatmap, and activity feed |
| State management | Existing project approach; a simple Flutter-native approach is sufficient | Keep fetched data and UI state synchronized |
| Development tools | **VS Code** or **Android Studio** | Code editing, debugging, and running the app |
| Source control | **Git and GitHub**, if configured | Version control and collaboration |

**Architecture:** Flutter app → direct GraphQL request to LeetCode → parse public response → update app state → cache the roster and primary username locally.

No custom backend is required or intended.

## 4. Architecture and Data Flow

1. **First launch:** Show primary-profile setup.
2. **Profile verification:** Query LeetCode's public GraphQL endpoint using the supplied username.
3. **Local persistence:** Save the verified primary username on the device.
4. **Dashboard:** Fetch the primary profile and teammate data needed for the leaderboard.
5. **Add teammate:** Verify the public profile, then add the username to the local roster.
6. **Profile detail:** Fetch available statistics, recent submissions, and calendar activity.
7. **Heatmap:** Convert real calendar data into date/count values, then render the seven-row scrollable calendar.
8. **Team activity:** Filter actual submission timestamps to the past seven days and group them by local calendar date.
9. **Sign Out:** Clear the primary-profile selection only, preserving teammates.
10. **Wipe teammates:** Clear teammate records only, preserving the primary profile.

Keep GraphQL operations in a service layer and parsing separate from the UI. Avoid network requests inside widget `build` methods.

## 5. Data and API Limitations

LeetCode's GraphQL endpoint is public-facing but unofficial for this app's use. Its schema, access rules, response fields, and rate limits may change.

- Some statistics or calendar data may not be available for every profile.
- Recent submissions may be limited in number or detail.
- Direct requests may fail due to network restrictions, rate limits, or API changes.
- Public GraphQL polling does not guarantee real-time updates or push notifications.
- Missing data should be shown as unavailable, not guessed.
- Do not request or store LeetCode passwords, session cookies, or private credentials.
- Do not add a proxy backend just to bypass access restrictions.

## 6. Privacy and Storage

- The primary LeetCode username and teammate roster are stored locally on the device.
- The app uses public profile data for the selected usernames.
- No custom user-account backend is part of the intended architecture.
- Sign Out resets the primary-profile selection but should preserve teammate records.
- Wiping teammates deletes teammate records only and should preserve the primary profile.
- Do not store passwords, private tokens, or LeetCode session cookies.
- Explain any additional data collection if future versions introduce it.

## 7. Suggested Project Structure

Adapt this to the actual repository and avoid replacing working code unnecessarily.

```text
lib/
  main.dart
  app.dart
  theme/
    app_theme.dart
    app_colors.dart
  models/
    leetcode_profile.dart
    teammate.dart
    leetcode_submission.dart
  services/
    leetcode_graphql_service.dart
    local_storage_service.dart
  repositories/
    profile_repository.dart
    teammate_repository.dart
  screens/
    primary_profile_setup_screen.dart
    dashboard_screen.dart
    profile_screen.dart
    teammate_detail_screen.dart
  widgets/
    leaderboard_card.dart
    submission_heatmap.dart
    team_activity_list.dart
    add_teammate_sheet.dart
    confirmation_dialog.dart
```

This is a suggested structure, not a requirement to reorganize an existing working app.

## 8. Quality Requirements

- Preserve the established dark theme and yellow/green accents.
- Make the layout responsive and prevent overflow.
- Provide loading, empty, error, and unavailable states.
- Validate usernames and prevent duplicate roster entries.
- Keep primary-profile data separate from teammate data.
- Ensure Sign Out and wipe-teammates actions have separate, carefully scoped behavior.
- Run `flutter analyze` and test first launch, later launch, profile verification failure, adding/removing teammates, sign out, heatmap scrolling, and API failure states.

## 9. Short Project Summary

**LEETO is a Flutter and Dart app for tracking LeetCode progress across a primary profile and a team of coding partners. It uses LeetCode's public GraphQL API to fetch available profile statistics, submissions, and calendar activity, while storing the primary username and teammate roster locally on the device. Its main features are a searchable leaderboard, teammate profiles, a horizontally scrollable LeetCode-style heatmap, and a seven-day team activity feed. The intended architecture has no custom backend and does not require LeetCode passwords.**

## 10. Important Implementation Note

This document describes the intended product and stack. Before using it as a final technical report or resume description, check the actual repository and `pubspec.yaml` to confirm which packages and features have truly been implemented. Do not claim an API field, chart, sorting mode, persistence feature, or screen is complete unless it works in the current code.

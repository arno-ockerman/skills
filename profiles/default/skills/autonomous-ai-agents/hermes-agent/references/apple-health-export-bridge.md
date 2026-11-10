# Apple Health / Apple Watch Export Bridge

Use this when a Hermes health-coach profile runs on Linux or outside iOS and the user wants Apple Health / Apple Watch analysis.

## Key Rule

Do not assume direct HealthKit access from Hermes. The reliable bridge is:

1. Apple Health / Apple Watch collects the data.
2. An iPhone export tool exports Health data to CSV or JSON.
3. The user sends the export file or screenshots to the Hermes health bot.
4. Hermes analyzes trends and turns them into practical actions.

## Practical Export Option Found in Session

- App Store listing confirmed: **Health Auto Export - JSON+CSV**
- App Store URL: `https://apps.apple.com/us/app/health-auto-export-json-csv/id1115567069`

## Recommended First Export Fields

- steps
- sleep
- resting heart rate
- HRV
- workouts
- active calories
- weight
- optional VO2 max

## Suggested MVP Workflow

- User sends meal photos and free-text meal descriptions to the health bot daily.
- User sends Apple Health exports or screenshots daily or a few times per week.
- Hermes keeps lightweight macro estimates and reviews recovery/load trends.

## Coaching Angle for Inflammatory / Recovery-Sensitive Users

When the user has reuma / ankylosing spondylitis or similar constraints:
- Interpret HRV, sleep, resting HR, and activity as recovery signals, not just performance signals
- Avoid aggressive training conclusions from single datapoints
- Prioritize consistency, recovery, mobility, walking, and adequate protein

## Important Wording

- Photo-based meal macros are estimates.
- Apple Health trend analysis should be framed probabilistically, not as medical diagnosis.
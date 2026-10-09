# DESIGN — CareSync Doctor Website

## 1. Design Direction
Clean, professional healthcare dashboard.

Visual principles:
- White/light neutral background
- Blue primary actions
- Green for healthy/completed states
- Amber for warnings
- Red only for urgent alerts
- Rounded cards
- Clear typography
- Large readable numbers
- Minimal clutter

## 2. Layout

```text
+----------------------------------------------------------+
| CareSync | Search | Notifications | Doctor Profile      |
+-------------+--------------------------------------------+
| Dashboard   |                                            |
| Patients    | Main content                                |
| Alerts      |                                            |
| Follow-ups  |                                            |
| Care Plans  |                                            |
| Settings    |                                            |
+-------------+--------------------------------------------+
```

Use a persistent sidebar on desktop.

## 3. Dashboard
Top KPI cards:
- Active Patients
- Needs Attention
- Low Adherence
- Follow-ups Due

Below:
- Adherence overview chart
- Urgent alerts
- Follow-ups due
- Recently updated care plans

## 4. Patient Table
Columns:
- Patient
- Age
- Care Plan
- Adherence
- Last Activity
- Follow-up
- Status
- Action

Provide:
- Search
- Filter
- Sort
- Pagination

## 5. Patient Details
Header:
- Patient name
- Patient ID
- Status
- Contact/nominee action

Sections:
- Current condition
- Active medicines
- Adherence
- Alerts
- Follow-up
- Documents
- Care-plan history

## 6. Care Plan Review
Use a two-column layout:

```text
Original Prescription/PDF | Structured AI Extraction
                         |
                         | Medicine
                         | Dose
                         | Time
                         | Food instruction
                         |
                         | [Approve]
                         | [Request Correction]
                         | [Reject]
```

Clearly label AI-extracted information as requiring doctor verification.

## 7. Alert Design
Levels:
- INFO
- WARNING
- URGENT

Every alert should show:
- Patient
- Reason
- Time
- Current adherence
- Recommended action
- Acknowledge button

## 8. Reassessment
Show:
- Previous care plan
- Current condition
- Doctor notes
- New prescription/document
- New care-plan preview
- Version number
- Approve button

## 9. Accessibility
- High contrast text
- Keyboard navigation
- Clear focus states
- Avoid color-only status indicators
- Descriptive labels
- Responsive desktop/tablet layout

## 10. Responsive Behavior
Desktop: full sidebar + multi-column dashboard.

Tablet: collapsible sidebar.

Mobile browser: stacked cards and tables converted to cards where necessary.

The primary doctor workflow is optimized for desktop.

# DESIGN --- AI-Assisted Post-Discharge Care System

## 1. Design Philosophy

The patient interface should be:

-   Simple
-   Mobile-first
-   Large and readable
-   Low cognitive load
-   Language-friendly
-   Voice-friendly
-   Action-oriented

The doctor interface should be:

-   Information-dense but organized
-   Fast to scan
-   Alert-driven
-   Focused on adherence and intervention

The design should avoid making the patient read the original medical
document repeatedly.

------------------------------------------------------------------------

## 2. Patient App Navigation

Recommended bottom navigation:

``` text
┌─────────────────────────────────────┐
│                                     │
│           Screen Content            │
│                                     │
├─────────┬─────────┬────────┬────────┤
│  Home   │  Week   │ Voice  │ Profile│
└─────────┴─────────┴────────┴────────┘
```

The four logical product tabs remain:

1.  Create/Update Care Plan
2.  Daily Dashboard
3.  Weekly Progress
4.  Doctor/Follow-up

For the patient app, Tab 4 can be represented through follow-up/profile
screens, while the full doctor dashboard remains a separate web portal.

------------------------------------------------------------------------

## 3. Tab 1 --- Create / Update Care Plan

### Screen

``` text
Create Your Care Plan

[ Upload Prescription / Discharge PDF ]

or

[ Take Prescription Photo ]

Current condition

┌─────────────────────────────┐
│ Tell us how you feel now... │
│                             │
└─────────────────────────────┘

[ 🎙 Speak ]

Preferred language
[ Kannada ▼ ]

[ Generate Care Plan ]
```

### Processing state

``` text
Analyzing prescription...
✓ Reading document
✓ Extracting medicines
✓ Understanding schedule
○ Preparing care plan
```

The system should clearly show that the result is awaiting doctor
approval.

------------------------------------------------------------------------

## 4. Care Plan Review Screen

Before activation:

``` text
AI-GENERATED CARE PLAN
Awaiting Doctor Approval

Morning
• Medicine A — 500 mg
• After breakfast

Afternoon
• Medicine B — 1 tablet
• After lunch

Night
• Medicine C — 1 tablet
• After dinner

Follow-up
08 Oct 2026

[ Doctor Approval Required ]
```

Patient should not be able to activate an unapproved plan.

------------------------------------------------------------------------

## 5. Tab 2 --- Daily Dashboard

### Main screen

``` text
Good Morning, Patient

Day 3 of 7
████████░░ 71%

TODAY

🌅 MORNING
11:00 AM

Medicine A
500 mg • 1 tablet
After food

[ ✓ MARK AS TAKEN ]

🎙 Ask about this medicine
```

Then:

``` text
☀️ AFTERNOON
2:00 PM

Medicine B
1 tablet

[ MARK AS TAKEN ]

🎙 Ask
```

And:

``` text
🌙 NIGHT
9:00 PM

Medicine C
1 tablet

[ MARK AS TAKEN ]

🎙 Ask
```

------------------------------------------------------------------------

## 6. Medication Status Design

Use clear text plus icons.

``` text
✓ TAKEN
● UPCOMING
⏰ DUE
⚠ MISSED
🔴 ESCALATED
```

Do not rely on color alone.

Example:

``` text
Morning   ✓ Taken
Afternoon ⏰ Due
Night     ● Upcoming
```

------------------------------------------------------------------------

## 7. Reminder Experience

### Normal reminder

``` text
💊 Medicine Reminder

Your morning medicine is due now.

Medicine A
500 mg
After breakfast

[ Mark as Taken ]
```

### Late reminder

``` text
⚠ Medicine Not Confirmed

Your medicine was scheduled earlier
and has not been marked as taken.

[ Mark as Taken ]
```

### Nominee escalation

``` text
⚠ Medication Alert

The patient's scheduled medicine
has not been confirmed.

A reminder has been sent to the patient
and nominee.
```

If voice notification is supported, play a short approved message.

------------------------------------------------------------------------

## 8. Voice Interaction

Every medication card can include:

``` text
🎙 Ask about medicine
```

Example questions:

-   "When should I take this?"
-   "Should I take it after food?"
-   "Which medicine is next?"
-   "What is my evening medicine?"

The voice response should be generated from the approved care plan.

For uncertain or clinical questions:

``` text
This information is not available
in your approved care plan.

Please contact your doctor.
```

------------------------------------------------------------------------

## 9. Tab 3 --- Weekly Progress

### Weekly view

``` text
WEEKLY MEDICATION PROGRESS

Monday      ✓ 100%
Tuesday     ✓ 100%
Wednesday   ⚠ 67%
Thursday    ✓ 100%
Friday      ✓ 100%
Saturday    ✕ 50%
Sunday      ● Today
```

### Day detail

``` text
Wednesday

Morning       ✓ Taken
Afternoon     ✕ Missed
Night         ✓ Taken

Daily adherence: 67%
```

### Escalation banner

If threshold is reached:

``` text
⚠ Follow-up Required

Repeated medication misses have been
reported to the hospital care team.

[ View Follow-up ]
```

------------------------------------------------------------------------

## 10. Doctor Dashboard

Desktop-first layout:

``` text
┌────────────────────────────────────────────────────┐
│ Hospital Care Dashboard                            │
├──────────┬──────────┬──────────┬──────────────────┤
│ Patients │ Adherence│ Alerts   │ Follow-ups       │
│   124    │   87%    │    8     │      15          │
├──────────┴──────────┴──────────┴──────────────────┤
│ Patient       Adherence       Status              │
│ Patient A       96%           ✓ Stable            │
│ Patient B       61%           ⚠ Attention         │
│ Patient C       43%           🔴 Escalated        │
└────────────────────────────────────────────────────┘
```

------------------------------------------------------------------------

## 11. Doctor Patient Detail

``` text
Patient: XYZ

Care Plan: V2
Status: Active

Current condition
-----------------
Patient-reported condition

Medication adherence
--------------------
87%

Missed doses
------------
3

Recent alerts
-------------
Repeated missed medication

Current medicines
------------------
Medicine A
Medicine B
Medicine C

Follow-up
---------
10 Oct 2026

[ Call Patient ]
[ Record Reassessment ]
[ Update Care Plan ]
```

------------------------------------------------------------------------

## 12. Doctor Reassessment

After contact/reassessment:

``` text
REASSESSMENT

Patient condition:
[____________________________]

Clinical decision:

( ) Continue current plan
( ) Update treatment
( ) Close care plan

New prescription:
[ Upload PDF ]

[ Create New Care Plan Version ]
```

If a new prescription is uploaded:

``` text
Care Plan V1
     ↓
Reassessment
     ↓
Care Plan V2
     ↓
Doctor Approval
     ↓
Patient Dashboard
```

------------------------------------------------------------------------

## 13. Care Plan Completion

If treatment is completed:

``` text
🎉 Care Plan Completed

Your doctor has marked this treatment
as completed.

Treatment period:
7 days

Medication adherence:
94%

[ View Treatment History ]
```

If more treatment is required:

``` text
Care Plan Updated

Your doctor has created a new care plan.

[ View New Plan ]
```

------------------------------------------------------------------------

## 14. Medicine Refill UI

When remaining quantity is low:

``` text
⚠ Medicine Running Low

Medicine A
Estimated supply: 2 days

[ Request Refill ]
```

After request:

``` text
Refill Request
✓ Request submitted

Status: Processing
```

For the hackathon, this can be a simulated pharmacy workflow.

------------------------------------------------------------------------

## 15. Accessibility

The app should support:

-   Large tap targets
-   Large readable text
-   Simple language
-   Voice interaction
-   Indian-language text
-   Text-to-speech
-   Speech-to-text
-   Clear icons + text
-   High contrast
-   Minimal medical jargon

The main medication action should always be obvious.

------------------------------------------------------------------------

## 16. Error States

### Prescription unreadable

``` text
We couldn't clearly read this prescription.

Please upload a clearer image or ask
your hospital staff for help.

[ Upload Again ]
```

### Ambiguous medicine

``` text
Medicine information needs doctor verification.

The system will not guess the medicine or dose.
```

### Notification failure

The backend should retry and log delivery failure.

### Voice unavailable

``` text
Voice is temporarily unavailable.

You can type your question instead.
```

------------------------------------------------------------------------

## 17. Design System

### Typography

Use:

-   Large headings
-   Medium-weight section titles
-   Highly readable body text
-   Larger medicine names
-   Prominent scheduled times

Suggested hierarchy:

``` text
H1 — 28–32 px
H2 — 22–24 px
H3 — 18–20 px
Body — 16 px
Secondary — 14 px
```

### Buttons

Primary:

``` text
[ MARK AS TAKEN ]
```

Secondary:

``` text
[ Ask by Voice ]
```

Danger/warning:

``` text
[ Contact Hospital ]
```

------------------------------------------------------------------------

## 18. Patient Dashboard Priority

The screen should answer three questions immediately:

1.  **What medicine should I take now?**
2.  **Did I take it?**
3.  **What happens if I miss it?**

Avoid displaying unnecessary medical information on the home screen.

------------------------------------------------------------------------

## 19. Notification Copy Guidelines

Notifications should be:

-   Short
-   Clear
-   Non-judgmental
-   Action-oriented

Good:

> "Your 11:00 AM medicine is due. Please confirm after taking it."

Avoid:

> "You failed to take your medication."

For nominee:

> "A scheduled medicine has not been confirmed. Please check with the
> patient."

------------------------------------------------------------------------

## 20. Design Principle

### Patient side

**Simple → Clear → Action**

### Doctor side

**Alert → Evidence → Action**

### AI

**Assist → Explain → Never independently prescribe**

### System

**Track → Escalate → Reassess → Create new care plan**

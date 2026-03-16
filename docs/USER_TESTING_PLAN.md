# EmoLor — User Testing Plan
## Autistic Children in Therapy Centres
**Testing Period:** Mid-March to May 2026 (6 Sessions, Biweekly)

---

## 1. Overview

### Goal
Evaluate the usability, engagement, and emotional appropriateness of EmoLor's **Child Dashboard** (Phase 1) and later the **Caregiver/Therapist interfaces** (Phase 2) through real-world observation with autistic children in centre settings.

### Research Questions
| # | Question |
|---|----------|
| RQ1 | Can children independently navigate the profile selection and home screen? |
| RQ2 | Do children understand and engage with the activity interface? |
| RQ3 | Does the reward system motivate continued engagement? |
| RQ4 | Are there UI elements that cause confusion, frustration, or sensory discomfort? |
| RQ5 | Do caregivers/therapists find their dashboard useful and easy to interpret? |

### Testing Phases
| Phase | Sessions | Focus |
|-------|----------|-------|
| **Phase 1** | Sessions 1 – 4 | Child Dashboard (profile select, home, activities, rewards) |
| **Phase 2** | Sessions 5 – 6 | Caregiver & Therapist Dashboards |

---

## 2. Session Schedule

| Session | Date | Focus | Status |
|---------|------|--------|--------|
| **Session 1** | ~17 March 2026 | Orientation + Basic Navigation (Profile Select → Home) | Planned |
| **Session 2** | ~31 March 2026 | Activity Engagement + First Impressions | Planned |
| **Session 3** | ~14 April 2026 | Reward System + Emotion Check-in | Planned |
| **Session 4** | ~28 April 2026 | Full Child Flow (End-to-End) + Iteration Validation | Planned |
| **Session 5** | ~12 May 2026 | Caregiver Dashboard Usability | Planned |
| **Session 6** | ~26 May 2026 | Therapist Dashboard + Full Integration Debrief | Planned |

> **Buffer rule:** If a child is unavailable or distressed on a session day, do not force participation — reschedule that child's tasks to the next session or a make-up slot.

---

## 3. Participant Profiles

### Target Participants
- **Age range:** 5 – 12 years
- **Diagnosis:** Autism Spectrum Disorder (ASD), varying support needs
- **Communication levels:** Mix of verbal, minimally verbal, and AAC users
- **Recommended group size per session:** 3 – 5 children (tested individually or in pairs, not as a group)

### Participant Roles (per session)
| Role | Who | Responsibility |
|------|-----|----------------|
| Child Participant | Autistic child | Uses the app |
| Support Adult | Familiar therapist/caregiver from the centre | Sits nearby, does NOT prompt unless child is distressed |
| Facilitator (You) | Researcher/Developer | Sets up device, gives minimal instructions, observes |
| Note-taker | Co-researcher or centre staff | Records behaviours, timestamps, quotes |

> **Golden rule:** the support adult is for the child's comfort, not to help them use the app. If they help too much, the data becomes unreliable.

---

## 4. Special Considerations for Autistic Participants

### Environment Setup
- [ ] Request a quiet room — no background noise or distractions
- [ ] Use a tablet mounted on a stand at the child's eye level (hands-free option)
- [ ] Keep lighting consistent (avoid glare or flickering)
- [ ] Have fidget tools/sensory breaks available
- [ ] Remove clutter from the testing table
- [ ] Keep the session to a soft cap of **20–30 minutes** per child

### Communication Adaptations
- Use **concrete, simple language** when giving instructions — one instruction at a time
- Prepare a **visual "what happens today" schedule** (e.g., a card showing: open app → play → done → sticker)
- Never use open-ended prompts like "What do you think?" — use binary or forced-choice: "Did you like this? Yes or No?"
- Accept and record **all communication modalities** (verbal, pointing, facial expression, body language)
- Have a **"I want to stop" card or signal** agreed on with the child before starting

### Child-Specific Accommodations
- Do a **3–5 minute warm-up** with something they enjoy before touching the app
- Allow the child to explore freely first before structured tasks begin
- If the child fixates on a specific screen or feature — **do not redirect** — document it (it may reveal strong preferences or confusion points)
- If a child becomes distressed at any point: stop, re-regulate, do not push

### What You Are NOT Allowed to Do
- Do not correct the child if they navigate "wrong"
- Do not ask "why" (too abstract for many autistic kids)
- Do not compare children to each other
- Do not share individual child data between families

---

## 5. Ethics & Consent

### Before Any Testing Begins (Pre-March)
- [ ] **Ethics approval:** Confirm your institution's IRB/ethics board requirements (if university project)
- [ ] **Centre permissions:** Written agreement from centre director
- [ ] **Parental/guardian consent forms:** Signed before child enters any session — include:
  - Purpose of the study
  - What data is collected (video, observations, no personal data stored)
  - Right to withdraw at any time without consequence
  - How findings will be used
- [ ] **Child assent:** Simple verbal or pictorial check — ask the child if they want to try the app today. If they show reluctance, do not proceed.
- [ ] **Video recording consent:** Separate clause, optional — record ONLY the screen (screen recording) unless face is required
- [ ] **Data handling:** All notes are anonymised (use codes like Child_A, Child_B, not names)

---

## 6. Pre-Session Checklist (Do Before Every Session)

### Technical Setup (1 hour before)
- [ ] Charge tablet to 100%
- [ ] Install latest APK / build from `flutter run --release`
- [ ] Log in to a **test caregiver account** and have 2–3 child profiles pre-created with fun names/avatars
- [ ] Ensure Supabase is connected and activities load correctly
- [ ] Disable notifications / Do Not Disturb on the device
- [ ] Set device brightness to medium (not auto-brightness that fluctuates)
- [ ] Open the app to the **Profile Selection screen** — this is where every session starts
- [ ] Prepare a **screen recording app** running in background (AZ Screen Recorder or similar)
- [ ] Test that audio (if any) works at a comfortable volume
- [ ] Keep a **paper observation sheet** and pen — do not type during the session (it distracts the child)

### Environment Setup
- [ ] Confirm quiet room is booked
- [ ] Arrange seating: child directly in front of tablet, you to the side (not behind)
- [ ] Place visual schedule card on the table
- [ ] Have reward stickers or preferred items ready (as a post-session thank-you, not mid-session bribe)
- [ ] Agree on the "stop signal" with the support adult and child beforehand

### Participant Prep
- [ ] Brief the support adult on what **not** to do (no prompting, no helping)
- [ ] Run a 5-minute warm-up activity (non-app related)
- [ ] Confirm child assent verbally or with picture card

---

## 7. Session-by-Session Testing Guide

---

### Session 1 — Orientation & Basic Navigation
**Date:** ~17 March 2026
**Duration:** 20–25 min per child
**Focus:** Can the child understand what the app is for? Can they get from the profile selection screen to the home screen?

#### Objectives
- Observe first impressions of the profile selection screen
- Check if children can identify and tap their own avatar/profile
- Check if children can reach the Home screen
- Identify any immediate confusion or delight

#### Structure

| Time | Activity |
|------|----------|
| 0:00 – 5:00 | Warm-up (non-app) + visual schedule intro |
| 5:00 – 8:00 | Free exploration — "This is an app, you can press anything you like" |
| 8:00 – 15:00 | Task 1: "Can you find your name and press it?" (Profile Selection) |
| 15:00 – 20:00 | Task 2: "What can you do on this screen?" (Home Screen exploration) |
| 20:00 – 25:00 | Wind-down, thank-you, sticker |

#### What to Observe
- Does the child recognise their avatar immediately or scan all profiles?
- Do they hesitate or tap wrong profiles?
- What is their reaction when they reach the Home screen? (smile, lean in, point, ignore)
- Do they try to tap things that are not tappable?
- Any confusion with layout, button size, or colour contrast?

#### Data to Collect
- Time to select profile (start of tap to profile selection confirmed)
- Number of incorrect taps before correct selection
- Free exploration areas (what did they tap first?)
- Verbal/non-verbal reactions

---

### Session 2 — Activity Engagement
**Date:** ~31 March 2026
**Duration:** 25–30 min per child
**Focus:** Do children understand how to start and complete an activity? Is the content engaging?

#### Objectives
- Evaluate the activity discovery flow (can they find and launch an activity?)
- Observe in-activity engagement (do they stay focused? for how long?)
- Identify drop-off points (where do they disengage or get stuck?)

#### Structure

| Time | Activity |
|------|----------|
| 0:00 – 3:00 | Quick warm-up + recap of last session (if same child) |
| 3:00 – 8:00 | Task: "Can you find something to play?" (navigate to Activities) |
| 8:00 – 18:00 | Let child play 1–2 activities — observe without interruption |
| 18:00 – 25:00 | Task: Prompt child to try a different activity — does the navigation make sense? |
| 25:00 – 30:00 | Cool-down |

#### What to Observe
- Do they understand the activity icons/titles or are they random-tapping?
- How long before they start the activity vs landing on it?
- Signs of engagement: leaning forward, tapping eagerly, vocalising
- Signs of disengagement: looking away, pushing device, closing app, stimming increase
- Do they complete the activity or abandon halfway?
- Does the difficulty feel right (not too easy/hard)?

#### Specific UI Checks
- Is the "Start" / "Play" button obvious enough?
- Do progress indicators (if any) make sense?
- Are instructions (text or audio) understood?

---

### Session 3 — Rewards & Emotion Check-in
**Date:** ~14 April 2026
**Duration:** 25–30 min per child
**Focus:** Does the reward system motivate children? Do they understand what they earned?

> **Note:** By this session, ensure the Rewards System is implemented in the build. See `features/rewards/` in the roadmap.

#### Objectives
- Observe emotional reaction to receiving stars/badges/points
- Check if children understand the reward collection screen
- Test emotion check-in feature (does the interface make sense for ASD kids?)

#### Structure

| Time | Activity |
|------|----------|
| 0:00 – 5:00 | Warm-up + "Last time we played, did you remember getting stars?" |
| 5:00 – 12:00 | Let child complete 1 activity — focus observation on the completion/reward animation |
| 12:00 – 20:00 | Guide to Rewards screen: "Can you find your stars/badges?" |
| 20:00 – 25:00 | Emotion check-in: "How are you feeling today?" — observe emoji selection |
| 25:00 – 30:00 | Structured cool-down |

#### What to Observe
- Do they react to completion animations? (positive reaction = good sign)
- Do they understand the points/stars → progress system?
- Are the emotion icons recognisable without labels?
- Do they select emotions that match observed affect — or are they guessing?
- Do they return to the rewards section voluntarily?

#### Caregiver Micro-Check (Optional — last 10 min)
- Ask the child's accompanying caregiver: "Did anything surprise you about what your child did in the app?"
- Note: do NOT show caregiver data collected from child's session at this stage

---

### Session 4 — Full Child Flow (End-to-End) + Iteration Validation
**Date:** ~28 April 2026
**Duration:** 30 min per child + 15 min debrief with support staff
**Focus:** Validate improvements made after Sessions 1–3. Full journey from login to reward.

#### Objectives
- Re-run the full child journey to check if fixes from Session 1–3 feedback resolved issues
- Capture any remaining friction points
- Begin collecting structured rating data (use simplified rating tool)

#### Structure

| Time | Activity |
|------|----------|
| 0:00 – 5:00 | Warm-up |
| 5:00 – 25:00 | Full uninterrupted journey: Profile Select → Home → Activity → Reward → Emotion Check-in |
| 25:00 – 30:00 | Simple rating: show 3 faces (😊 😐 😞) — "How did you feel using the app?" |
| 30:00 – 45:00 | Debrief with therapists/caregivers present — gather collective observations |

#### Simple Rating Tool for the Child
Print three cards (A4, laminated):
```
😊 = Liked it
😐 = It was okay
😞 = Didn't like it
```
Ask the child to point to each section of the app on the screen, then point to which face card represents how they felt. Record it.

#### Debrief Questions for Centre Staff (15 min)
1. Which parts of the app did the children seem most drawn to?
2. Were there any moments where children seemed confused or distressed?
3. How does the app compare to other digital tools used at your centre?
4. What would make the app better for the children you work with?
5. Would you recommend children use this at home? Why or why not?

---

### Session 5 — Caregiver Dashboard Usability
**Date:** ~12 May 2026
**Duration:** 30–40 min with caregiver participants (adults only this session)
**Focus:** Can caregivers interpret their child's data? Is the dashboard useful?

> This session is with caregivers only (parents/guardians who gave consent). Children do NOT need to be present.

#### Objectives
- Evaluate caregiver ability to navigate from Profile Selection → Caregiver Dashboard
- Test if activity progress, engagement trends, and performance stats are understandable
- Assess the analytics and report generation features

#### Participants
- Recruit 3–5 caregivers of children who participated in Sessions 1–4
- Mix of tech-savvy and non-tech-savvy participants

#### Structure

| Time | Activity |
|------|----------|
| 0:00 – 5:00 | Brief intro — explain what they're seeing |
| 5:00 – 15:00 | Task 1: "Can you find how many activities your child completed this week?" |
| 15:00 – 25:00 | Task 2: "Can you find what emotion your child reported?" |
| 25:00 – 30:00 | Task 3: "Can you download a report?" |
| 30:00 – 40:00 | Semi-structured interview — open discussion |

#### Interview Questions for Caregivers
1. When you first looked at the dashboard, what did you notice first?
2. Is there any information you wish was there but isn't?
3. Did anything confuse you?
4. How often would you realistically use this dashboard? (Daily / Weekly / Monthly / Never)
5. Would you feel comfortable sharing this data with your child's therapist? Why?

#### Metrics to Track
- Task completion rate (did they complete the task without help?)
- Time on task for each task
- Number of wrong navigation paths taken
- Rating: Overall usefulness (1 = not useful, 5 = very useful)

---

### Session 6 — Therapist Dashboard + Final Debrief
**Date:** ~26 May 2026
**Duration:** 40–60 min with therapist participants + final synthesis discussion
**Focus:** Therapist workflow evaluation + closure on all testing phases

#### Participants
- 2–3 therapists from the centre
- Ideally therapists who observed Sessions 1–4

#### Structure

| Time | Activity |
|------|----------|
| 0:00 – 5:00 | Intro + context |
| 5:00 – 20:00 | Therapist tasks: client records, session scheduling, notes, engagement trends |
| 20:00 – 30:00 | Task: "Link a client account using the share code feature" |
| 30:00 – 40:00 | Task: "Add clinical notes for a client after viewing their activity data" |
| 40:00 – 60:00 | Final debrief — all stakeholders (caregivers, therapists, centre director if possible) |

#### Therapist Tasks (Specific Screens to Test)
| Task | Screen | Expected Path |
|------|--------|---------------|
| View a child's profile | My Clients → Client Record | Easy — rate difficulty |
| Check activity engagement | Client Record → Clinical History | Medium |
| Add a session note | Client Record → Notes tab | Easy |
| Schedule a session | Sessions → Schedule tab | Medium |
| Link a new client | My Clients → Link New Account | Hard — observe errors |
| Generate engagement report | Reports → Engagement Trends → Export | Hard |

#### Final Debrief Questions (All Stakeholders)
1. Overall, how well does EmoLor fit into your centre's workflow?  
2. What is the single most important thing to improve before launch?  
3. Would your centre consider officially using this app? Under what conditions?  
4. What features would you want added in the next version?  

---

## 8. Data Collection Templates

### Observation Sheet (Print one per child per session)

```
SESSION:       DATE:          CHILD CODE:
FACILITATOR:   NOTE-TAKER:    SESSION DURATION:

TASK COMPLETION LOG
Task | Started? | Completed? | Time Taken | Errors | Notes
-----|----------|------------|------------|--------|------
     |          |            |            |        |
     |          |            |            |        |

BEHAVIOURAL OBSERVATIONS
- Engagement signs (circle all that apply):
  Leaning forward / Eye contact / Pointing / Smiling / Vocalising / Tapping eagerly

- Disengagement signs (circle all relevant):
  Looking away / Pushing device / Stimming increase / Verbal refusal / Closing app

UNPROMPTED INTERACTIONS
(Note exact screen child navigated to spontaneously):


CONFUSION POINTS
(Note any moment child paused > 10 seconds, tapped wrong, or looked at adult):


CHILD'S EMOTIONAL REACTION (tick one column per phase)
                      😊 Positive | 😐 Neutral | 😞 Negative
Profile Selection     |           |           |
Home Screen           |           |           |
Activity              |           |           |
Reward Screen         |           |           |
Emotion Check-in      |           |           |

NOTES / QUOTES / OBSERVATIONS:


```

---

### Between-Session Fix Tracker

After each session, fill this in before the next one:

```
SESSION:         DATE:       FILLED BY:

ISSUES FOUND THIS SESSION
#  | Screen          | Issue Description              | Severity (H/M/L) | Fix by Session #
---|-----------------|-------------------------------|------------------|------------------
1  |                 |                               |                  |
2  |                 |                               |                  |
3  |                 |                               |                  |

POSITIVE FINDINGS (keep these, don't change)

CHANGES MADE BEFORE NEXT SESSION
- 
- 
-
```

---

## 9. Between-Session Development Priority

Use this guide to decide **what to fix between each session**:

### After Session 1 → Before Session 2
- Fix any navigation dead-ends found in profile selection
- Ensure activity list is populated with real content (min. 4 activities)
- Fix any crashes seen during testing
- Adjust button sizes if children had trouble tapping targets

### After Session 2 → Before Session 3
- Implement or polish in-activity progress indicators
- Fix reward animation if it wasn't triggering
- Adjust difficulty if all children finished too quickly or too slowly
- Fix any audio issues if children were listening for sounds

### After Session 3 → Before Session 4
- Incorporate emoji changes if emotion check-in icons were misunderstood
- Improve reward screen clarity
- Address any recurring confusion patterns across multiple children

### After Session 4 → Before Session 5
- Finalise child dashboard based on all feedback
- Ensure caregiver dashboard reflects real data from Sessions 1–4 activities
- Test: does real progress data appear correctly in caregiver view?

### After Session 5 → Before Session 6
- Fix caregiver dashboard issues found in Session 5
- Ensure therapist screens are fully functional with linked client data

---

## 10. Metrics Summary (What You Are Measuring)

### Child-Focused Metrics

| Metric | How to Measure |
|--------|----------------|
| Task Success Rate | % of children who completed each task without adult help |
| Time on Task | Seconds from task given → task completed |
| Error Rate | Number of wrong taps / wrong screens before success |
| Engagement Duration | How long child stayed on each screen voluntarily |
| Emotional Reaction | Observed affect at key moments (rated 😊 😐 😞) |
| Return Behaviour | Did child go back to a screen voluntarily? |
| Drop-off Point | Which screen caused child to disengage or stop |

### Adult-Focused Metrics (Sessions 5–6)

| Metric | How to Measure |
|--------|----------------|
| Task Completion Rate | % of tasks completed without help |
| Time on Task | Seconds from task given → task completed |
| Error Rate | Wrong navigation paths before reaching goal |
| Perceived Usefulness | 1–5 Likert rating after session |
| Data Literacy | Can they interpret engagement charts correctly? |

---

## 11. What "Done and Ready" Means Before Each Session

### For Session 1 — Must Have
- [ ] Profile Selection screen working (3+ profiles with avatars)
- [ ] Navigation from profile → Home screen working
- [ ] Home screen with at least static content rendered
- [ ] No crashes in this flow

### For Session 2 — Must Have  
- [ ] At least 4 playable activities listed
- [ ] Activity tap → activity screen navigation working
- [ ] Basic in-activity UI (even if placeholder content)
- [ ] Back navigation from activity → home

### For Session 3 — Must Have
- [ ] Completion triggers a visible reward (animation or points)
- [ ] Rewards screen shows accumulated rewards
- [ ] Emotion check-in screen functional

### For Session 4 — Must Have
- [ ] All of the above, bug-fixed based on Sessions 1–3
- [ ] Session 1–3 top issues resolved

### For Session 5 — Must Have
- [ ] Caregiver dashboard showing real progress data from test activities
- [ ] Engagement trends chart populated
- [ ] Report export (at minimum PDF) functional

### For Session 6 — Must Have
- [ ] Therapist dashboard with client records functional
- [ ] Notes system working
- [ ] Session scheduling working
- [ ] Link client feature working

---

## 12. Final Report Structure

After all 6 sessions, produce a **User Testing Report** with these sections:

1. **Executive Summary** — 1 page, key findings and top 3 recommendations
2. **Methodology** — participant details, session structure, ethical notes
3. **Child Dashboard Findings** (Sessions 1–4)
   - What worked well
   - What needs improvement (with screenshots and specific observations)
   - Heatmap of most/least used features
4. **Caregiver Dashboard Findings** (Session 5)
5. **Therapist Dashboard Findings** (Session 6)
6. **Cross-Cutting Themes** — patterns across all sessions
7. **Prioritised Recommendation List** — ranked by impact and effort
8. **Next Steps** — what to fix before public release

---

## 13. Quick Reference — Do's and Don'ts in Sessions

| ✅ DO | ❌ DON'T |
|-------|---------|
| Sit beside, not behind the child | Stand over the child |
| Observe silently during free exploration | Jump in to help when child pauses |
| Note exact screen names when recording issues | Use vague notes like "confusion on app" |
| Stop immediately if child is distressed | Push through discomfort for data |
| Accept all communication (pointing, sounds) | Ask "why did you do that?" |
| Keep sessions short (≤30 min per child) | Run over time to collect more data |
| Record only the screen, not the child's face (unless consent) | Record without consent |
| Debrief with centre staff after each session | Dismiss staff observations |
| Treat each session as its own baseline | Assume Session 2 children remember Session 1 |
| Celebrate all child participation | React negatively to unexpected behaviour |

---

*Document Version 1.0 — Created March 2026*
*Update this document after each session with key findings.*

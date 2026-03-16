# EmoLor Architecture Refinement
## Unified Child-Caregiver Interface

### Overview
EmoLor now features a unified interface where children and caregivers share the same app experience, with children using profiles under their caregiver's account. Therapists have separate authentication and access to all children's data.

## User Roles & Access

### 1. Caregiver (Parent/Guardian)
- **Authentication**: Email/password login through Supabase Auth
- **Capabilities**:
  - Create and manage multiple child profiles (no auth accounts needed for children)
  - Help children login by selecting their profile
  - Set up child accounts (name, age, avatar, preferences)
  - View dashboard showing all children's progress
  - Monitor activity completion, rewards, and learning progress
  - Access insights and recommendations
- **Access Level**: Limited to their own children only

### 2. Child Profile (Under Caregiver Account)
- **Authentication**: No separate auth account - selected from profile list
- **Capabilities**:
  - Play learning activities and games
  - Track emotions and feelings
  - Earn rewards (completion-based and time-based)
  - View their own progress and rewards
  - Personalize experience (colors, themes)
- **Access Level**: Can only access their own profile data

### 3. Therapist
- **Authentication**: Separate email/password login
- **Capabilities**:
  - View all assigned children's profiles and data
  - Monitor emotional tracking and patterns
  - View activity progress and engagement
  - Create and manage therapy sessions
  - Add notes and recommendations
  - Generate insights and reports
- **Access Level**: Access to all assigned children (can be assigned to specific children or view all)

### 4. Admin (System Administrator)
- **Authentication**: Separate email/password login
- **Capabilities**:
  - Manage all users, profiles, and content
  - View system-wide analytics
  - Manage activities and content
  - Assign therapists to children
  - System configuration
- **Access Level**: Full system access

## App Flow

### Initial Launch Flow
```
1. App Start
   ↓
2. Splash Screen (check auth state)
   ↓
3a. Not Authenticated → Login Screen
    - Caregiver/Parent tab
    - Therapist tab
    - Admin tab
   ↓
3b. Authenticated (Caregiver) → Child Profile Selection
    - Shows all child profiles under account
    - Option to create new profile
    - Option to access caregiver dashboard
   ↓
3c. Authenticated (Therapist/Admin) → Their respective dashboard
```

### Caregiver Flow
```
1. Login as Caregiver
   ↓
2. Child Profile Selection Screen
   - View all child profiles
   - Select child to play
   - Create new profile
   - Access caregiver dashboard (settings icon)
   ↓
3a. Select Child → Child Home Screen
    - Learning activities
    - Games
    - Emotion tracking
    - Rewards display
   ↓
3b. Caregiver Dashboard
    - All children overview
    - Progress charts
    - Activity completion stats
    - Rewards earned
    - Insights and recommendations
```

### Child Experience Flow
```
1. Caregiver selects child profile
   ↓
2. Child Home Screen
   - Welcome message with child's name
   - Available activities (age-appropriate)
   - Current rewards/badges
   - Emotion check-in
   ↓
3. Select Activity
   - Play game/activity
   - Track progress in real-time
   - Earn stars (1-3 based on performance)
   - Earn rewards on completion
   ↓
4. Complete Activity
   - Show achievement animation
   - Award rewards (points, badges, stars)
   - Update progress
   - Suggest next activity
```

### Therapist Flow
```
1. Login as Therapist
   ↓
2. Therapist Dashboard
   - List of assigned children
   - Recent activities across all children
   - Flagged concerns/patterns
   ↓
3. Select Child
   - View detailed profile
   - Emotion tracking history
   - Activity progress
   - Session notes
   - Generate reports
   ↓
4. Manage Sessions
   - Schedule sessions
   - Add session notes
   - Set goals
   - Track progress toward goals
```

## Database Structure

### Key Tables

#### `users` (Auth accounts)
- Only for: caregivers, therapists, admins
- NOT for children

#### `child_profiles` (No auth accounts)
- Linked to caregiver via `caregiver_id`
- Can be assigned to therapist via `therapist_id`
- Stores: name, age, avatar, preferences
- Multiple profiles per caregiver

#### `activities` (Games & Learning Content)
- Reusable content for all children
- Age-appropriate filtering
- Type: game, exercise, story, art
- Difficulty levels

#### `activity_progress` (Per Child, Per Activity)
- Tracks completion status
- Time spent (seconds)
- Stars earned (1-3)
- Score/performance
- Unique constraint: one record per child per activity

#### `rewards` (Achievement System)
- Types:
  - **completion**: Finished an activity
  - **time_milestone**: Spent X minutes learning
  - **streak**: Consecutive days active
  - **achievement**: Special accomplishments
  - **special**: Custom rewards
- Points system
- Badge/icon display

## Reward System

### Completion-Based Rewards
- **Activity Completion**: 10-50 points based on difficulty
- **Perfect Score**: Bonus 20 points
- **First Try Success**: Bonus 15 points
- **3 Stars Earned**: Bonus 25 points

### Time-Based Rewards
- **5 minutes**: "Getting Started" badge
- **15 minutes**: "Learning Champion" badge  
- **30 minutes**: "Super Learner" badge
- **1 hour total**: "Dedication Star" badge
- **Daily streak**: 5 points per consecutive day

### Achievement Rewards
- **All activities in category**: "Category Master" badge
- **10 activities completed**: "Explorer" badge
- **50 activities completed**: "Expert" badge
- **100% accuracy**: "Perfectionist" badge

## Progress Tracking

### For Caregivers (Dashboard View)
- Overview of all children
- Each child card shows:
  - Name and avatar
  - Total points earned
  - Activities completed today/this week
  - Current streak
  - Recent rewards
  - Time spent learning
- Detailed view per child:
  - Activity history
  - Emotion tracking patterns
  - Progress charts (daily/weekly/monthly)
  - Rewards collection
  - Upcoming goals

### For Children (Engaging Display)
- Visual progress bars
- Star collection display
- Badge showcase
- Points counter with animations
- "Next reward" preview
- Activity suggestions based on age and progress

### For Therapists (Clinical View)
- All assigned children in one view
- Filter by concerns/patterns
- Engagement metrics
- Emotional wellbeing trends
- Activity participation rates
- Session notes and goals
- Export reports

## Technical Implementation

### State Management
- **Riverpod** for state management
- Providers for:
  - Auth state
  - Selected child profile
  - Activity progress
  - Rewards
  - User preferences

### Navigation
- **go_router** for declarative routing
- Routes:
  - `/` - Splash
  - `/login` - Login screen
  - `/profile-select` - Child profile selection
  - `/child/home` - Child home (requires profile)
  - `/child/activity/:id` - Play activity
  - `/child/create` - Create profile
  - `/child/edit/:id` - Edit profile
  - `/caregiver` - Caregiver dashboard
  - `/therapist` - Therapist dashboard
  - `/admin` - Admin dashboard

### Authentication Guards
- Check auth state on app start
- Redirect based on role
- Protect routes by role
- Store selected child profile in app state

## Key Features

### Child Profile Management
✅ Create multiple child profiles
✅ Select active child profile
✅ Edit profile (name, age, avatar)
✅ Soft delete profiles
✅ Profile preferences (colors, themes)

### Activity System
- Age-appropriate content filtering
- Progress tracking per child
- Real-time progress updates
- Star rating system (1-3 stars)
- Completion tracking

### Reward System
- Automatic reward calculation
- Multiple reward types
- Points accumulation
- Badge collection
- Visual feedback and animations

### Dashboard & Analytics
- Multi-child overview for caregivers
- Individual child details
- Progress charts and graphs
- Engagement metrics
- Insight recommendations

### Therapist Tools
- All children view
- Individual child deep dive
- Session management
- Notes and goals
- Report generation

## Security & Privacy

### Row Level Security (RLS)
- Caregivers: Access only their children
- Therapists: Access only assigned children
- Admins: Full access
- Children: No direct database access (via caregiver)

### Data Access Policies
- Child profiles: Caregiver owns, therapist views
- Progress: Caregiver & therapist can view
- Rewards: Caregiver & therapist can view
- Sessions: Therapist owns, caregiver views
- Activities: Public read for active content

## Next Steps for Implementation

1. ✅ Update database schema
2. ✅ Create child profile models and services
3. ✅ Build profile selection screen
4. ✅ Build profile creation screen
5. ⏳ Update login flow for unified interface
6. ⏳ Create child home screen
7. ⏳ Build activity player screens
8. ⏳ Implement reward calculation logic
9. ⏳ Build caregiver dashboard
10. ⏳ Update therapist dashboard for new structure
11. ⏳ Implement progress tracking
12. ⏳ Add analytics and insights
13. ✅ UCD031 – View Message / Feedback (conversation view, unread badges)
14. ✅ UCD032 – Download Media (media preview, gallery/downloads saving, permissions)
15. ✅ UCD033 – Respond To Session Invitation (accept/decline with conflict check, therapist dashboard)

---
*This architecture supports the core vision of EmoLor: Making emotional learning accessible, engaging, and trackable for children, while empowering caregivers and therapists with the insights they need.*

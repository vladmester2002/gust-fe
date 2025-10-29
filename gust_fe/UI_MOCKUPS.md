# GUST App - UI/UX Mockups

## Design System Overview

### Color Palette
- **Primary Purple**: #6A1B9A (Deep Purple 800)
- **Accent Teal**: #00897B (Teal 600)
- **Accent Coral**: #FF6F61
- **Success Green**: #43A047
- **Warning Orange**: #FB8C00
- **Error Red**: #E53935
- **Info Blue**: #1E88E5
- **Background Grey**: #F5F5F5
- **Soft Lavender**: #E1BEE7

### Typography
- **Display**: 48px, Bold
- **Headline**: 32px, Semi-bold
- **Title**: 20-24px, Semi-bold
- **Body**: 16px, Regular
- **Caption**: 12-14px, Regular

---

## 1. Login Screen

```
┌─────────────────────────────────────────┐
│                                         │
│    [Gradient Background: Teal→Purple]   │
│                                         │
│              ╭─────╮                    │
│              │ 🍬  │  GUST               │
│              ╰─────╯                    │
│                                         │
│       Track Your Sugar Journey          │
│                                         │
│    ╭───────────────────────────────╮   │
│    │  ┌──────────────────────────┐ │   │
│    │  │ 📧 Email                 │ │   │
│    │  └──────────────────────────┘ │   │
│    │                               │   │
│    │  ┌──────────────────────────┐ │   │
│    │  │ 🔒 Password              │ │   │
│    │  └──────────────────────────┘ │   │
│    │                               │   │
│    │  [────── LOGIN ──────]        │   │
│    │                               │   │
│    │  Forgot Password?             │   │
│    │                               │   │
│    │  Don't have an account?       │   │
│    │  Sign Up                      │   │
│    ╰───────────────────────────────╯   │
│                                         │
└─────────────────────────────────────────┘
```

**Features:**
- Full-screen gradient background
- Circular app icon with shadow
- Large, spacious input fields
- Primary action button with icon
- Secondary actions as text links
- No app bar for immersive experience

---

## 2. Home/Dashboard Screen

```
┌─────────────────────────────────────────┐
│  GUST Dashboard           🔄            │ Soft Lavender AppBar
├─────────────────────────────────────────┤
│                                         │
│  ╭───────────────────────────────────╮ │
│  │ [Gradient: Teal→Purple]           │ │
│  │                                   │ │
│  │ ⭕ Welcome back,                  │ │
│  │ 👤 John Doe                       │ │
│  │                        [🔥 7 days]│ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭─────────────────╮  ╭──────────────╮ │
│  │  ✅              │  │  📊          │ │
│  │                 │  │              │ │
│  │     5           │  │   50g        │ │
│  │  Logs Today     │  │ Daily Goal   │ │
│  ╰─────────────────╯  ╰──────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │ [Light Gradient Background]       │ │
│  │                                   │ │
│  │ 🥤  TODAY'S SUGAR                 │ │
│  │                                   │ │
│  │     35 / 50 g      [✅ GOOD]     │ │
│  │                                   │ │
│  │ ████████░░░░░░░░░  70%            │ │
│  │                                   │ │
│  │ ❤️  Remaining: 15 g               │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │ 📈 Sugar Trends (7 Days)          │ │
│  │                                   │ │
│  │     ╱╲                            │ │
│  │    ╱  ╲    ╱╲                     │ │
│  │   ╱    ╲  ╱  ╲  ╱                │ │
│  │  ╱      ╲╱    ╲╱                  │ │
│  │ ───────────────────────           │ │
│  │  M  T  W  T  F  S  S              │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │ 🍕 Today's Foods                  │ │
│  │                                   │ │
│  │ ╭───────────────────────────────╮ │ │
│  │ │ ⚪ Chocolate Bar               │ │ │
│  │ │    🕐 09:30  😊 Happy          │ │ │
│  │ │                         [25g]  │ │ │
│  │ ╰───────────────────────────────╯ │ │
│  │                                   │ │
│  │ ╭───────────────────────────────╮ │ │
│  │ │ ⚪ Orange Juice    ⚡ craving  │ │ │
│  │ │    🕐 14:15  😐 Neutral        │ │ │
│  │ │                         [10g]  │ │ │
│  │ ╰───────────────────────────────╯ │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │ 🎯 Daily Goal Tracker       ✏️   │ │
│  │                                   │ │
│  │    Goal: 50 g sugar/day           │ │
│  │    Tap to set your goal.          │ │
│  ╰───────────────────────────────────╯ │
│                                         │
└─────────────────────────────────────────┘
│  🏠    📊    ➕    👥    👤            │ Bottom Nav
└─────────────────────────────────────────┘
```

**Key Features:**
- Gradient welcome card with streak badge
- Quick stats showing logs and goal
- Enhanced sugar intake card with gradient, status badge, and percentage
- Line chart for 7-day trends
- Individual food log cards with all details
- Tappable goal tracker card
- Bottom navigation bar

---

## 3. Sugar Log Creation Dialog

```
        ┌─────────────────────────────┐
        │ [Gradient: Teal→Purple]     │
        │ ➕ Log Sugar Intake      ✕  │
        ├─────────────────────────────┤
        │                             │
        │ 🥤 ┌─────────────────────┐  │
        │    │ Sugar (g)           │  │
        │    └─────────────────────┘  │
        │                             │
        │ 🍔 ┌─────────────────────┐  │
        │    │ Product/Food Name   │  │
        │    └─────────────────────┘  │
        │                             │
        │ 🏷️ ┌─────────────────────┐  │
        │    │ Sugar Type          │  │
        │    └─────────────────────┘  │
        │                             │
        │ 📝 ┌─────────────────────┐  │
        │    │ Context Note        │  │
        │    │                     │  │
        │    └─────────────────────┘  │
        │                             │
        │ 📍 ┌─────────────────────┐  │
        │    │ Location            │  │
        │    └─────────────────────┘  │
        │                             │
        │ ╭─────────────────────────╮ │
        │ │ 📅 Date                 │ │
        │ │ 10/19/2025 (today only) │ │
        │ ╰─────────────────────────╯ │
        │                             │
        │ ╭─────────────────────────╮ │
        │ │ 🕐 Time          ✏️     │ │
        │ │ 11:48 AM                │ │
        │ ╰─────────────────────────╯ │
        │                             │
        │ ╭─────────────────────────╮ │
        │ │ 💡 Tip: Pick the time   │ │
        │ │    you consumed sugar   │ │
        │ ╰─────────────────────────╯ │
        │                             │
        │ Emotion                     │
        │ ╭─────────────────────────╮ │
        │ │ 😊 Neutral          ▼   │ │
        │ ╰─────────────────────────╯ │
        │                             │
        │ ╭─────────────────────────╮ │
        │ │ ⚡ Was craving?    [⚪─]│ │
        │ ╰─────────────────────────╯ │
        │                             │
        ├─────────────────────────────┤
        │ [Grey Background]           │
        │                             │
        │  [Cancel]      [➕  Log]    │
        │                             │
        └─────────────────────────────┘
```

**Features:**
- Gradient header with close button
- All inputs use consistent styling
- Icons for every field
- Date/Time in separate styled containers
- Info tip with lightbulb
- Emotion dropdown with emojis
- Craving toggle with bolt icon
- Footer with action buttons

---

## 4. Analytics Screen

```
┌─────────────────────────────────────────┐
│  ◀  Analytics                           │
├─────────────────────────────────────────┤
│                                         │
│  ╭─────────────┬─────────────────────╮ │
│  │   Week  ▼   │  📅 Oct 13-19      │ │
│  ╰─────────────┴─────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  Weekly Average                   │ │
│  │                                   │ │
│  │         38.5g                     │ │
│  │    ┌─────────────┐                │ │
│  │    │   ██████    │                │ │
│  │    │  ████████   │                │ │
│  │    │ ██████████  │ vs 50g goal   │ │
│  │    └─────────────┘                │ │
│  │     77% of goal                   │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  Daily Breakdown                  │ │
│  │                                   │ │
│  │  Mon  ██████████░░  45g           │ │
│  │  Tue  ████████░░░░  35g           │ │
│  │  Wed  ████████████  52g  ⚠️      │ │
│  │  Thu  ██████░░░░░░  30g           │ │
│  │  Fri  ████████░░░░  38g           │ │
│  │  Sat  ██████████░░  48g           │ │
│  │  Sun  ████████░░░░  36g           │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  Top Foods This Week              │ │
│  │                                   │ │
│  │  1️⃣ Chocolate Bar         25g    │ │
│  │  2️⃣ Orange Juice          20g    │ │
│  │  3️⃣ Cookies                18g    │ │
│  │  4️⃣ Soda                   15g    │ │
│  │  5️⃣ Ice Cream              12g    │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  Emotional Patterns               │ │
│  │                                   │ │
│  │  😊 Happy       8 logs            │ │
│  │  😐 Neutral     5 logs            │ │
│  │  😢 Sad         2 logs            │ │
│  │  😰 Stressed    3 logs            │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  [────── Export Data ──────]           │
│                                         │
└─────────────────────────────────────────┘
```

**Features:**
- Time period selector (Week/Month/Year)
- Date range picker
- Circular progress for weekly average
- Daily breakdown with horizontal bars
- Top foods ranking
- Emotional pattern analysis
- Export functionality button

---

## 5. Profile Screen

```
┌─────────────────────────────────────────┐
│  ◀  Profile                    ⚙️       │
├─────────────────────────────────────────┤
│                                         │
│         ╭─────────────────╮            │
│         │  ┌───────────┐  │            │
│         │  │           │  │            │
│         │  │    👤     │  │            │
│         │  │           │  │            │
│         │  └───────────┘  │            │
│         │                 │            │
│         │   John Doe      │            │
│         │ john@email.com  │            │
│         ╰─────────────────╯            │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  🏆 Achievements                  │ │
│  │                                   │ │
│  │  [🔥7]  [📊50] [⭐️100] [💪30]    │ │
│  │  Streak  Logs  Points  Days      │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  📈 Progress Overview             │ │
│  │                                   │ │
│  │  Total Logs: 156                  │ │
│  │  ██████████████████░░  78%        │ │
│  │                                   │ │
│  │  Days Tracked: 45                 │ │
│  │  ████████████████░░░░  68%        │ │
│  │                                   │ │
│  │  Goal Met: 32/45 days             │ │
│  │  █████████████░░░░░░░  71%        │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  👤 Account                       │ │
│  │  ────────────────────────────────│ │
│  │  📧 Email: john@email.com         │ │
│  │  🎯 Daily Goal: 50g               │ │
│  │  🔔 Notifications: ON             │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  ⚙️  Settings                     │ │
│  │  ────────────────────────────────│ │
│  │  🔔 Notification Settings    ›    │ │
│  │  🎨 Theme & Appearance       ›    │ │
│  │  🔒 Privacy & Security       ›    │ │
│  │  📱 About GUST               ›    │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  [────── Logout ──────]                │
│                                         │
└─────────────────────────────────────────┘
```

**Features:**
- Profile header with avatar
- Achievement badges (streak, logs, points, days)
- Progress bars for key metrics
- Account information summary
- Settings menu with sections
- Logout button

---

## 6. Community Screen

```
┌─────────────────────────────────────────┐
│  Community              🔍  ➕          │
├─────────────────────────────────────────┤
│                                         │
│  ╭─────────────────┬─────────────────╮ │
│  │  Following  ▼   │  🔥 Trending    │ │
│  ╰─────────────────┴─────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  👤 Sarah M.          2h ago      │ │
│  │  ────────────────────────────────│ │
│  │                                   │ │
│  │  Just completed my 30-day         │ │
│  │  streak! 🎉 Feeling amazing       │ │
│  │  about controlling my sugar       │ │
│  │  intake!                          │ │
│  │                                   │ │
│  │  🎯 30g avg | 🔥 30 days          │ │
│  │                                   │ │
│  │  ❤️  24    💬 8    🔄 3          │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  👤 Mike R.           5h ago      │ │
│  │  ────────────────────────────────│ │
│  │                                   │ │
│  │  [Photo: Healthy meal]            │ │
│  │                                   │ │
│  │  Found this amazing sugar-free    │ │
│  │  dessert recipe! 😋                │ │
│  │                                   │ │
│  │  ❤️  42    💬 15   🔄 8          │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  👤 Emma T.           1d ago      │ │
│  │  ────────────────────────────────│ │
│  │                                   │ │
│  │  Tips for beginners:              │ │
│  │  1. Start with realistic goals    │ │
│  │  2. Log everything honestly       │ │
│  │  3. Don't beat yourself up        │ │
│  │  4. Celebrate small wins! 🎊      │ │
│  │                                   │ │
│  │  ❤️  67    💬 23   🔄 12         │ │
│  ╰───────────────────────────────────╯ │
│                                         │
└─────────────────────────────────────────┘
```

**Features:**
- Filter tabs (Following/Trending)
- Search and create post buttons
- Post cards with user info
- Text, images, and achievement displays
- Like, comment, share interactions
- Timestamps

---

## 7. Notification System

```
┌─────────────────────────────────────────┐
│  🔔 Notifications                       │
├─────────────────────────────────────────┤
│                                         │
│  Today                                  │
│  ╭───────────────────────────────────╮ │
│  │  🎯 Daily Reminder          2h    │ │
│  │  Don't forget to log your         │ │
│  │  afternoon snacks!                │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  📊 Weekly Report Ready!    5h    │ │
│  │  Your week 42 analytics are       │ │
│  │  ready to view. Great progress!   │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  Yesterday                              │
│  ╭───────────────────────────────────╮ │
│  │  🔥 Streak Milestone!      1d     │ │
│  │  Congratulations! You've reached  │ │
│  │  a 7-day streak! Keep it up! 🎉   │ │
│  ╰───────────────────────────────────╯ │
│                                         │
│  ╭───────────────────────────────────╮ │
│  │  ⚠️  Goal Exceeded         1d     │ │
│  │  You exceeded your daily goal by  │ │
│  │  15g. Review your intake.         │ │
│  ╰───────────────────────────────────╯ │
│                                         │
└─────────────────────────────────────────┘
```

**Features:**
- Grouped by date
- Different notification types with icons
- Timestamps
- Actionable messages
- Color coding by importance

---

## 8. Onboarding Flow

### Screen 1: Welcome
```
┌─────────────────────────────────────────┐
│                                         │
│              ╭─────╮                    │
│              │ 🍬  │                    │
│              ╰─────╯                    │
│                                         │
│         Welcome to GUST                 │
│                                         │
│     Your Personal Sugar                 │
│     Tracking Companion                  │
│                                         │
│        [Illustration: Sweet foods       │
│         with measurement indicators]    │
│                                         │
│             ⚪⚪⚪⚫                      │
│                                         │
│            [Next →]                     │
│                                         │
└─────────────────────────────────────────┘
```

### Screen 2: Features
```
┌─────────────────────────────────────────┐
│                                         │
│        Track Your Intake                │
│                                         │
│     Log every sugary food and           │
│     drink with detailed context         │
│                                         │
│        [Illustration: Phone with        │
│         logging interface]              │
│                                         │
│      ✓ Quick logging                    │
│      ✓ Detailed analytics               │
│      ✓ Emotional patterns               │
│                                         │
│             ⚪⚪⚫⚪                      │
│                                         │
│      [← Back]      [Next →]            │
│                                         │
└─────────────────────────────────────────┘
```

### Screen 3: Goal Setting
```
┌─────────────────────────────────────────┐
│                                         │
│         Set Your Goal                   │
│                                         │
│     How much sugar do you want          │
│     to consume per day?                 │
│                                         │
│     Recommended: 25-50g                 │
│                                         │
│        ┌─────────────────┐              │
│        │      50g        │              │
│        └─────────────────┘              │
│                                         │
│     [─────○─────────────]               │
│     0g               100g                │
│                                         │
│             ⚪⚫⚪⚪                      │
│                                         │
│      [← Back]   [Get Started]          │
│                                         │
└─────────────────────────────────────────┘
```

---

## 9. Empty States

### No Logs Yet
```
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│            ╭─────────╮                  │
│            │  📝 💭  │                  │
│            ╰─────────╯                  │
│                                         │
│        No Logs Yet                      │
│                                         │
│   Start tracking your sugar intake      │
│   by adding your first log!             │
│                                         │
│     [➕ Add Your First Log]             │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

### No Community Posts
```
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│            ╭─────────╮                  │
│            │  👥 💬  │                  │
│            ╰─────────╯                  │
│                                         │
│    No Posts to Show                     │
│                                         │
│   Be the first to share your            │
│   journey with the community!           │
│                                         │
│     [➕ Create First Post]              │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

---

## 10. Loading & Error States

### Loading State
```
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│              ╭─────╮                    │
│              │ 🍬  │                    │
│              ╰─────╯                    │
│                                         │
│         Loading your data...            │
│                                         │
│              ⏳ ⏳ ⏳                    │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

### Error State
```
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│              ╭─────╮                    │
│              │ ⚠️   │                   │
│              ╰─────╯                    │
│                                         │
│      Oops! Something went wrong         │
│                                         │
│   We couldn't load your data.           │
│   Please check your connection.         │
│                                         │
│       [🔄 Try Again]                    │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

---

## Design Principles

### 1. Visual Hierarchy
- Use size, color, and spacing to establish importance
- Primary actions are larger and more prominent
- Secondary information uses lighter text colors

### 2. Consistency
- All cards use 16px corner radius
- Spacing follows 8px grid system
- Icons are consistently sized (20-32px)
- Color usage is semantic and consistent

### 3. Feedback & Affordance
- Buttons have clear hover/pressed states
- Loading states show progress
- Success/error messages use appropriate colors
- Interactive elements have sufficient touch targets (48x48px minimum)

### 4. Accessibility
- Text contrast ratio meets WCAG AA standards (4.5:1 minimum)
- All interactive elements are keyboard accessible
- Icons paired with labels
- Alternative text for images

### 5. Progressive Disclosure
- Show essential information first
- Use expandable sections for details
- Modals/dialogs for focused tasks
- Bottom sheets for contextual actions

### 6. Data Visualization
- Use colors to indicate status (red=bad, green=good)
- Charts are simple and easy to understand
- Progress bars show completion percentage
- Trends use familiar line/bar chart patterns

---

## Interaction Patterns

### Gestures
- **Swipe Right**: Navigate back
- **Pull to Refresh**: Reload data
- **Long Press**: Show context menu
- **Tap**: Primary action
- **Double Tap**: Quick like (community posts)

### Animations
- **Fade**: For dialog/modal entry/exit
- **Slide**: For navigation transitions
- **Scale**: For button press feedback
- **Ripple**: For touch feedback on Android

### Transitions
- Duration: 200-300ms for most animations
- Easing: Use Material Design easing curves
- Page transitions: Slide with fade
- Modal entry: Scale + fade from center

---

## Responsive Design

### Mobile (< 600dp)
- Single column layout
- Full-width cards
- Bottom navigation bar
- Stack elements vertically

### Tablet (600-840dp)
- Two-column layout for lists
- Side navigation drawer option
- Larger touch targets
- More whitespace

### Desktop (> 840dp)
- Three-column layout
- Persistent navigation sidebar
- Larger charts and visualizations
- Mouse hover interactions

---

## Accessibility Features

### Screen Reader Support
- All images have alt text
- Form inputs have labels
- Buttons have descriptive text
- Navigation is logical and sequential

### Keyboard Navigation
- Tab through all interactive elements
- Enter/Space activates buttons
- Escape closes modals
- Arrow keys navigate lists

### High Contrast Mode
- Increased contrast ratios
- Thicker borders
- Bolder text weights
- More distinct colors

### Font Scaling
- Supports system font size settings
- Layout adapts to larger text
- Minimum font size: 12px
- Maximum scaling: 200%

---

## Dark Mode (Future Enhancement)

### Color Adjustments
- Background: #121212
- Surface: #1E1E1E
- Primary: #BB86FC (lighter purple)
- Accent: #03DAC6 (lighter teal)
- Text: #FFFFFF / #B0B0B0

### Design Considerations
- Reduce white surfaces to prevent eye strain
- Use elevated surfaces for depth
- Maintain contrast ratios
- Test with night mode users

---

## Performance Considerations

### Image Optimization
- Use WebP format for images
- Lazy load images below fold
- Cache frequently used images
- Compress assets

### Animation Performance
- Use GPU-accelerated properties (transform, opacity)
- Avoid animating layout properties
- Throttle scroll listeners
- Use requestAnimationFrame

### Data Loading
- Show skeleton screens while loading
- Implement infinite scroll for lists
- Cache data locally
- Prefetch likely next screens

---

## Microcopy & Messaging

### Tone of Voice
- **Friendly**: "Great job logging today! 🎉"
- **Encouraging**: "Keep up the good work!"
- **Informative**: "You've exceeded your daily goal by 15g"
- **Supportive**: "No worries, tomorrow is a new day!"

### Error Messages
- **Clear**: "Couldn't save your log"
- **Helpful**: "Check your internet connection"
- **Actionable**: [Try Again] button
- **Non-technical**: Avoid jargon

### Empty States
- **Encouraging**: "Start your journey today!"
- **Action-oriented**: Include clear CTA
- **Visual**: Use friendly illustrations
- **Brief**: Keep text concise

---

## Component Library Reference

### Buttons
- **Primary**: Purple background, white text
- **Secondary**: Outlined, purple border
- **Danger**: Red background for destructive actions
- **Text**: No background, purple text

### Cards
- **Standard**: White bg, 16px radius, elevation 2-4
- **Gradient**: Teal→Purple gradient
- **Interactive**: Hover effects, ripple on tap

### Input Fields
- **Default**: Grey border, purple focus state
- **With Icon**: Prefix icon in purple
- **Error**: Red border, error text below
- **Disabled**: Grey background, reduced opacity

### Icons
- **Size**: 20px (small), 24px (medium), 32px (large)
- **Style**: Material Icons (outlined)
- **Color**: Matches semantic meaning

---

*Last Updated: October 19, 2025*
*Version: 1.0*

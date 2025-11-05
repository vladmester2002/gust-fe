# Dashboard Visual Mockup

## New Dashboard Layout

```
╔════════════════════════════════════════════╗
║  Hello, John              🔥 12    🔄      ║  <- Personalized app bar
╠════════════════════════════════════════════╣
║                                            ║
║  ┌──────────────────────────────────────┐ ║
║  │ ✅ Welcome back! Logged in securely.│ ║  <- Biometric welcome (brief)
║  └──────────────────────────────────────┘ ║
║                                            ║
║  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ║
║  ┃  ✓ Today's Sugar    [+ Add]        ┃ ║
║  ┃  Looking good                       ┃ ║
║  ┃                                     ┃ ║
║  ┃         72 / 75 g                  ┃ ║  <- HERO CARD
║  ┃         ▓▓▓▓▓▓▓▓▓▓░░               ┃ ║  <- Big focus
║  ┃  🏁 3g left today          96%     ┃ ║
║  ┃  💡 7-day average: 68g             ┃ ║
║  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ║
║                                            ║
║  ┌──────┐  ┌──────┐  ┌──────┐           ║
║  │ ✏️   │  │ 🔥  │  │ ✅  │           ║  <- Quick actions
║  │ Edit │  │ 12  │  │  3  │           ║
║  │ Goal │  │Strk │  │Logs │           ║
║  └──────┘  └──────┘  └──────┘           ║
║                                            ║
║  ┌────────────────────────────────────┐  ║
║  │ 📊 Sugar Trends (7 Days)           │  ║
║  │                                    │  ║  <- Weekly chart
║  │    ╱╲                              │  ║
║  │   ╱  ╲    ╱╲                       │  ║
║  │  ╱    ╲  ╱  ╲                      │  ║
║  │ ╱      ╲╱    ╲                     │  ║
║  │ Mon Tue Wed Thu Fri Sat Sun        │  ║
║  └────────────────────────────────────┘  ║
║                                            ║
║  ┌────────────────────────────────────┐  ║
║  │ 🍽️ Today's Logs      3 entries    │  ║
║  │                                    │  ║
║  │ ○ Coca Cola              [22g]    │  ║  <- Log entries
║  │   14:30  😊 Happy                 │  ║
║  │                                    │  ║
║  │ ○ Chocolate Bar          [35g]    │  ║
║  │   16:15  😐 Neutral  ⚡ craving   │  ║
║  │                                    │  ║
║  │ ○ Ice Cream              [15g]    │  ║
║  │   20:00  😊 Happy                 │  ║
║  └────────────────────────────────────┘  ║
║                                            ║
║                                            ║
║                           ┌──────────┐    ║  <- FAB always visible
║                           │ + Add Log│    ║
║                           └──────────┘    ║
╚════════════════════════════════════════════╝
```

## Empty State Layout

```
╔════════════════════════════════════════════╗
║  Hello, Sarah             🔥 0     🔄      ║
╠════════════════════════════════════════════╣
║                                            ║
║  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ║
║  ┃  ⚠️ Today's Sugar    [+ Add]       ┃ ║
║  ┃  Looking good                       ┃ ║
║  ┃                                     ┃ ║
║  ┃          0 / 50 g                  ┃ ║  <- Zero state
║  ┃         ░░░░░░░░░░░░               ┃ ║
║  ┃  🏁 50g left today          0%     ┃ ║
║  ┃  💡 7-day average: 0g              ┃ ║
║  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ║
║                                            ║
║  ┌──────┐  ┌──────┐  ┌──────┐           ║
║  │ ✏️   │  │ 🔥  │  │ ✅  │           ║
║  │ Edit │  │  0  │  │  0  │           ║
║  │ Goal │  │Strk │  │Logs │           ║
║  └──────┘  └──────┘  └──────┘           ║
║                                            ║
║  ┌────────────────────────────────────┐  ║
║  │ 📊 Sugar Trends (7 Days)           │  ║
║  │                                    │  ║
║  │  (empty chart - flat line at 0)   │  ║
║  └────────────────────────────────────┘  ║
║                                            ║
║  ┌────────────────────────────────────┐  ║
║  │ 🍽️ Today's Logs      0 entries    │  ║
║  │                                    │  ║
║  │          ⊕                         │  ║  <- Friendly empty state
║  │    No logs yet today               │  ║
║  │  Tap + above to start tracking     │  ║
║  └────────────────────────────────────┘  ║
║                                            ║
║                           ┌──────────┐    ║
║                           │ + Add Log│    ║
║                           └──────────┘    ║
╚════════════════════════════════════════════╝
```

## Over Goal State Layout

```
╔════════════════════════════════════════════╗
║  Hello, Mike              🔥 8     🔄      ║
╠════════════════════════════════════════════╣
║                                            ║
║  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ║
║  ┃  ⚠️ Today's Sugar    [+ Add]       ┃ ║
║  ┃  Over goal                          ┃ ║  <- Red warning
║  ┃                                     ┃ ║
║  ┃         92 / 75 g                  ┃ ║  <- Red number
║  ┃         ▓▓▓▓▓▓▓▓▓▓▓▓▓              ┃ ║  <- Red bar
║  ┃  🚩 Over by 17g           123%     ┃ ║  <- Red badge
║  ┃  💡 7-day average: 78g             ┃ ║
║  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ║
║                                            ║
║  (rest of layout same...)                 ║
╚════════════════════════════════════════════╝
```

## Color Coding

### Status Colors:
- **GREEN** (Looking good): 0-80% of goal
  - Progress bar: Green
  - Number: Purple
  - Status text: Green

- **ORANGE** (Almost there): 80-100% of goal
  - Progress bar: Orange
  - Number: Purple
  - Status text: Orange

- **RED** (Over goal): >100% of goal
  - Progress bar: Red
  - Number: Red
  - Status text: Red

## Interactive Elements

### Tappable Areas:
1. **Refresh icon** (top right) → Reload all data
2. **Hero card "Add" button** → Open log modal
3. **Edit Goal card** → Open goal setting dialog
4. **Any log entry** → Edit that log
5. **Floating Action Button** → Open log modal

### Visual Feedback:
- Cards have elevation (shadow)
- Buttons have ink splash on tap
- Progress bar animates
- Welcome banner fades in/out

## Spacing & Typography

```
Font Sizes:
- Main number: 64px (huge!)
- Secondary number: 32px
- Status text: 16px
- Body text: 14px
- Labels: 13px
- Captions: 12px

Spacing:
- Between sections: 20dp (spaceLG)
- Card padding: 16dp (spaceMD)
- Element spacing: 8-12dp
- Touch targets: 48dp minimum
```

## Accessibility Notes

✓ High contrast colors
✓ Large touch targets
✓ Clear visual hierarchy
✓ Icon + text labels
✓ Readable font sizes
✓ Logical screen reader order

---

**Design Goal**: User should understand their status in < 2 seconds
**Primary Action**: Logging should be < 3 taps
**Visual Priority**: Today's progress > Quick actions > Historical data

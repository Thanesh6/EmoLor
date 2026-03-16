# EmoLor Figma Design Guide

## 🎨 Color Palette

### Primary Colors
```
Primary (Purple):    hsl(262, 52%, 47%)  | #7C3AED | rgb(124, 58, 237)
Secondary (Pink):    hsl(340, 82%, 67%)  | #F472B6 | rgb(244, 114, 182)
Accent (Teal):       hsl(173, 58%, 65%)  | #5EEAD4 | rgb(94, 234, 212)
Success (Green):     hsl(142, 76%, 36%)  | #16A34A | rgb(22, 163, 74)
Warning (Orange):    hsl(38, 92%, 50%)   | #F59E0B | rgb(245, 158, 11)
Destructive (Red):   hsl(0, 84%, 60%)    | #EF4444 | rgb(239, 68, 68)
```

### Neutral Colors
```
Background:          hsl(250, 100%, 98%) | #FAFAFF | rgb(250, 250, 255)
Card:                hsl(0, 0%, 100%)    | #FFFFFF | rgb(255, 255, 255)
Foreground (Text):   hsl(260, 40%, 15%)  | #1A0F33 | rgb(26, 15, 51)
Muted:               hsl(250, 30%, 94%)  | #EEEBF7 | rgb(238, 235, 247)
Muted Text:          hsl(260, 15%, 45%)  | #6B6380 | rgb(107, 99, 128)
Border:              hsl(250, 30%, 88%)  | #DBD5ED | rgb(219, 213, 237)
```

### Emotion Colors
```
Happy:               hsl(48, 100%, 67%)  | #FFEB99 | rgb(255, 235, 153)
Sad:                 hsl(221, 83%, 53%)  | #3B82F6 | rgb(59, 130, 246)
Calm:                hsl(173, 58%, 65%)  | #5EEAD4 | rgb(94, 234, 212)
Excited:             hsl(340, 82%, 67%)  | #F472B6 | rgb(244, 114, 182)
Angry:               hsl(0, 84%, 60%)    | #EF4444 | rgb(239, 68, 68)
Scared:              hsl(262, 52%, 47%)  | #7C3AED | rgb(124, 58, 237)
```

## 🎭 Gradients

### Hero Gradient
```
Direction: 135°
Stop 1: hsl(262, 83%, 58%) | #8B5CF6 at 0%
Stop 2: hsl(340, 82%, 67%) | #F472B6 at 100%
```

### Child Gradient (Playful)
```
Direction: 135°
Stop 1: hsl(173, 58%, 75%) | #99F6E4 at 0%
Stop 2: hsl(48, 100%, 77%) | #FEF3C7 at 100%
```

### Card Gradient (Subtle)
```
Direction: 180°
Stop 1: hsl(0, 0%, 100%)    | #FFFFFF at 0%
Stop 2: hsl(250, 100%, 99%) | #FCFCFF at 100%
```

## 📏 Spacing & Sizing

### Border Radius
```
Base (lg):     16px
Medium (md):   14px
Small (sm):    12px
```

### Container
```
Max Width:     1400px (2xl breakpoint)
Padding:       32px (2rem)
```

### Grid Breakpoints
```
Mobile:        < 768px
Tablet:        768px - 1024px
Desktop:       1024px - 1400px
Large Desktop: > 1400px
```

## 🖋️ Typography

### Font Family
System font stack (or use Inter/Satoshi for similar feel):
```
-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif
```

### Text Styles

#### Headings
```
H1 (Hero):
  Size: 48px (mobile) / 56px (desktop)
  Weight: Bold (700)
  Line Height: 1.2
  Color: Foreground

H2 (Section):
  Size: 32px (mobile) / 40px (desktop)
  Weight: Bold (700)
  Line Height: 1.3
  Color: Foreground

H3 (Card Title):
  Size: 20px
  Weight: Bold (700)
  Line Height: 1.4
  Color: Foreground

H4 (Feature Title):
  Size: 16px
  Weight: Bold (700)
  Line Height: 1.4
  Color: Foreground
```

#### Body Text
```
Large Body:
  Size: 20px
  Weight: Regular (400)
  Line Height: 1.6
  Color: Muted Text

Body:
  Size: 16px
  Weight: Regular (400)
  Line Height: 1.6
  Color: Muted Text

Small:
  Size: 14px
  Weight: Regular (400)
  Line Height: 1.5
  Color: Muted Text
```

#### Buttons
```
Large Button:
  Size: 18px
  Weight: Medium (500)
  Letter Spacing: 0px
  Color: Primary Foreground (white)

Default Button:
  Size: 16px
  Weight: Medium (500)
  Letter Spacing: 0px
```

## 🔲 Components

### Button
```
Primary:
  Background: Primary (#7C3AED)
  Text: White
  Padding: 12px 32px (large) / 10px 24px (default)
  Border Radius: 16px
  Shadow: 0 10px 40px -5px rgba(124, 58, 237, 0.25)
  
  Hover:
    Shadow: 0 0 30px rgba(139, 92, 246, 0.3)
    Transform: slight scale or brightness

Outline:
  Background: Transparent
  Text: Foreground
  Border: 2px solid Border color
  Padding: 10px 30px
  Border Radius: 16px
```

### Card
```
Background: White (#FFFFFF)
Border: 1px solid Border (#DBD5ED)
Border Radius: 16px
Padding: 32px
Shadow: 0 4px 20px -2px rgba(124, 58, 237, 0.15)

Hover:
  Shadow: 0 10px 40px -5px rgba(124, 58, 237, 0.25)
  Transition: smooth (0.2s)
```

### Icon Container
```
Size: 56x56px
Border Radius: 12px
Background: Gradient or solid color
Icon Size: 28x28px (centered)
```

### Badge
```
Background: Primary/10 (rgba(124, 58, 237, 0.1))
Text: Primary (#7C3AED)
Text Size: 14px
Weight: Medium (500)
Padding: 8px 16px
Border Radius: 999px (full rounded)
```

## 📱 Layout Structure

### Landing Page Sections

#### 1. Hero Section
```
Background: Light gradient overlay (opacity 10%)
Padding: 80px vertical
Language Selector: Top right, absolute
Content: Centered, max-width 896px

Elements:
- Badge with Sparkles icon
- H1 title with gradient text
- Large body description
- Two buttons (Primary + Outline)
```

#### 2. Features Section
```
Padding: 80px vertical
Grid: 4 columns (desktop) / 2 columns (tablet) / 1 column (mobile)
Gap: 32px
Card: Icon container + title + description
```

#### 3. Key Features
```
Background: Muted/30 (rgba(238, 235, 247, 0.3))
Padding: 80px vertical
Grid: 2 columns
Layout: Icon (left) + content (right)
```

#### 4. CTA Section
```
Background: Hero Gradient
Border Radius: 24px
Padding: 48px
Text: White
Shadow: Elevated
```

#### 5. Footer
```
Border Top: 1px solid Border
Padding: 32px vertical
Text: Muted, centered
```

## 🎯 Icon Library

Use **Lucide Icons** or similar:
- Palette (child features)
- Heart (caregiver features)
- Users (therapist features)
- Brain (admin features)
- Sparkles (highlights)
- ArrowRight (CTAs)

## 🌙 Dark Mode

### Colors
```
Background:          hsl(260, 40%, 8%)   | #0F0817
Card:                hsl(260, 35%, 12%)  | #1A1425
Foreground:          hsl(250, 30%, 96%)  | #F5F3FA
Primary:             hsl(262, 83%, 58%)  | #8B5CF6
```

## 📋 Auto Layout Tips

### Card Component
```
- Auto layout: Vertical
- Padding: 32px
- Gap: 16px
- Fill: Horizontal
- Hug: Vertical
```

### Button Component
```
- Auto layout: Horizontal
- Padding: 12px 32px
- Gap: 8px (for icon + text)
- Hug: Both directions
```

### Feature Grid
```
- Auto layout: Horizontal Wrap
- Gap: 32px
- Fixed width items: ~280px
```

## 🚀 Quick Start Steps

1. **Create Color Styles**: Add all colors from palette
2. **Create Text Styles**: Set up typography system
3. **Build Components**: Button, Card, Badge, Icon Container
4. **Create Frames**: Mobile (375px), Tablet (768px), Desktop (1440px)
5. **Layout Sections**: Build from top to bottom
6. **Apply Shadows**: Use defined shadow values
7. **Add Icons**: Use Lucide or similar icon set
8. **Prototype**: Add click interactions for navigation

## 📦 Figma Plugin Recommendations

- **Iconify**: Access Lucide icons directly
- **Unsplash**: Free images for mockups
- **Color Palettes**: Quick color management
- **Auto Layout**: Better spacing control
- **Content Reel**: Generate placeholder text

---

**Note**: All HSL values can be converted to HEX/RGB using Figma's color picker. Simply paste the HSL value and Figma will convert it automatically.

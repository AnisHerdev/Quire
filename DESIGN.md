---
name: Quire
description: A scholarly note organization and search app
colors:
  primary: "#012D1D"
  secondary: "#795900"
  background: "#FAF9F4"
  surface: "#FAF9F4"
  error: "#BA1A1A"
typography:
  display:
    fontFamily: "Lora, serif"
    fontSize: "48px"
    fontWeight: 700
    lineHeight: 1.16
  headline:
    fontFamily: "Lora, serif"
    fontSize: "32px"
    fontWeight: 600
    lineHeight: 1.25
  title:
    fontFamily: "Lora, serif"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: 1.33
  body:
    fontFamily: "Inter, sans-serif"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.55
  label:
    fontFamily: "Inter, sans-serif"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.42
rounded:
  sm: "4px"
  md: "8px"
  lg: "12px"
  xl: "16px"
  pill: "24px"
spacing:
  sm: "8px"
  md: "16px"
  lg: "24px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#FFFFFF"
    rounded: "{rounded.pill}"
    padding: "16px 24px"
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.xl}"
    padding: "16px"
---

# Design System: Quire

## 1. Overview

**Creative North Star: "The Academic Sanctuary"**

The design system for Quire evokes the quiet focus of a well-lit library and the tactile satisfaction of a curated study desk. The personality is disciplined yet inviting—clean, warm, and highly organized. The aesthetic leans into Modern Corporate with Minimalist influences, utilizing high-quality serif typography for content to provide a scholarly rhythm. The interface prioritizes focus by reducing visual noise, using deep greens and warm ambers to create a grounded, studious atmosphere that differentiates itself from typical cold, clinical productivity tools.

**Key Characteristics:**
- Scholarly yet modern aesthetic
- High-contrast, legible typography pairing (Lora & Inter)
- Warm off-white backgrounds (Light Mode) and deep charcoal (Dark Mode) to reduce eye strain
- Soft, pill-shaped buttons and generously rounded cards

## 2. Colors

The palette centers on a "Deep Forest" green for growth and stability, paired with "Warm Gold" accents.

### Primary
- **Deep Forest Green** (#012D1D): The anchor color used for prominent actions, main headers, and selected states. It grounds the interface.

### Secondary
- **Warm Gold** (#795900): Used for highlights, secondary actions, and search focus rings. It adds an academic, library-like warmth.

### Neutral
- **Warm Off-White** (#FAF9F4): The default surface and background color in Light Mode, chosen specifically to reduce glare and eye strain during long reading sessions.
- **Dark Charcoal** (#0F100F): The deep background color in Dark Mode, avoiding pitch black to maintain softness.

### Named Rules
**The Warmth Rule.** Neutral surfaces in Light Mode should never be pure white (#FFFFFF) unless used as an absolute highlight. They must always carry a slight warm tint (#FAF9F4) to feel tactile and printed.

## 3. Typography

**Display Font:** Lora (with serif fallback)
**Body Font:** Inter (with sans-serif fallback)

**Character:** A dual-font strategy balancing editorial elegance (Lora) with functional, high-legibility UI clarity (Inter).

### Hierarchy
- **Display** (700, 48px, 1.16): Used for hero moments or major screen titles.
- **Headline** (600, 32px, 1.25): Primary page headers and prominent section dividers.
- **Title** (600, 24px, 1.33): Card titles, folder names, or list item headers.
- **Body** (400, 18px, 1.55): Standard reading text. Line length should be capped around 65-75ch for optimal reading rhythm.
- **Label** (600, 14px, 1.42, 0.01em spacing): UI metadata, timestamps, button labels, and small file indicators.

### Named Rules
**The Scholarly Rhythm Rule.** Headings must use Lora to establish the academic context, while all functional UI text (buttons, metadata, navigation) strictly uses Inter to maintain instant legibility.

## 4. Elevation

The system relies primarily on tonal layers and very soft ambient shadows, avoiding harsh lines.

### Shadow Vocabulary
- **Ambient Glow** (`box-shadow: 0 4px 20px rgba(27, 67, 50, 0.08)`): Used on cards in Light Mode. It is specifically tinted with the primary green, avoiding pure black/gray shadows, to maintain warmth.

### Named Rules
**The Tonal Depth Rule.** In Dark Mode, depth is achieved by lightening the surface color (e.g., `#161716` or `#2A2B2A`) against the deeper background (`#0F100F`), rather than using drop shadows.

## 5. Components

### Buttons
- **Shape:** Pill-shaped (24px radius).
- **Primary:** Deep Forest Green (#012D1D) background with white text.
- **Hover / Focus:** Shifts to a slightly lighter green container color (#1B4332).

### Cards / Containers
- **Corner Style:** 16px (rounded-xl) for a modern, approachable feel.
- **Background:** Warm Off-White (#FAF9F4) in Light Mode, Elevated Charcoal (#2A2B2A) in Dark Mode.
- **Shadow Strategy:** Ambient Glow shadow in Light Mode; pure tonal elevation in Dark Mode.
- **Internal Padding:** Generous spacing (16px - 24px) to ensure content never feels cramped.

### Inputs / Search Bar
- **Style:** 12px (rounded-lg) radius to distinguish them from the pill-shaped action buttons.
- **Focus:** Highlighted with a Warm Gold focus ring.

### File Indicators / Chips
- **Style:** Small, rounded-md (4px) labels.
- **State:** Each file type utilizes semantic colors (e.g., red for PDF, blue for DOCX) applied as a subtle 10% opacity background or via the icon itself.

## 6. Do's and Don'ts

### Do:
- **Do** use extremely soft, tinted shadows (e.g., `rgba(27, 67, 50, 0.08)`) instead of generic gray/black drop shadows.
- **Do** maintain a 1.5x line height for body text to ensure readability during heavy research/reading tasks.
- **Do** ensure all vertical spacing is a multiple of the 8px base unit.

### Don't:
- **Don't** use pure white (`#FFFFFF`) as a main background in Light Mode; always use the Warm Off-White (`#FAF9F4`).
- **Don't** mix Lora and Inter within the same paragraph or block. Use Lora for the header, Inter for the body.
- **Don't** use identical, endless card grids without visual breaks.
- **Don't** use high-contrast black shadows.

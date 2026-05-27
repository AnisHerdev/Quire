---
name: Academic Sanctuary
colors:
  surface: '#faf9f4'
  surface-dim: '#dbdad5'
  surface-bright: '#faf9f4'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f4ef'
  surface-container: '#efeee9'
  surface-container-high: '#e9e8e3'
  surface-container-highest: '#e3e3de'
  on-surface: '#1b1c19'
  on-surface-variant: '#414844'
  inverse-surface: '#30312e'
  inverse-on-surface: '#f2f1ec'
  outline: '#717973'
  outline-variant: '#c1c8c2'
  surface-tint: '#3f6653'
  primary: '#012d1d'
  on-primary: '#ffffff'
  primary-container: '#1b4332'
  on-primary-container: '#86af99'
  inverse-primary: '#a5d0b9'
  secondary: '#795900'
  on-secondary: '#ffffff'
  secondary-container: '#fece65'
  on-secondary-container: '#755700'
  tertiary: '#002d1c'
  on-tertiary: '#ffffff'
  tertiary-container: '#00452e'
  on-tertiary-container: '#75b393'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#c1ecd4'
  primary-fixed-dim: '#a5d0b9'
  on-primary-fixed: '#002114'
  on-primary-fixed-variant: '#274e3d'
  secondary-fixed: '#ffdf9f'
  secondary-fixed-dim: '#eec058'
  on-secondary-fixed: '#261a00'
  on-secondary-fixed-variant: '#5b4300'
  tertiary-fixed: '#b1f0ce'
  tertiary-fixed-dim: '#95d4b3'
  on-tertiary-fixed: '#002114'
  on-tertiary-fixed-variant: '#0e5138'
  background: '#faf9f4'
  on-background: '#1b1c19'
  surface-variant: '#e3e3de'
typography:
  display-lg:
    fontFamily: Source Serif 4
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Source Serif 4
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Source Serif 4
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-md:
    fontFamily: Source Serif 4
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 48px
  xl: 64px
  gutter: 24px
  margin_mobile: 16px
  margin_desktop: 40px
---

## Brand & Style
The design system for this note organization and search app is rooted in the "Academic Sanctuary" concept. It evokes the quiet focus of a well-lit library and the tactile satisfaction of a curated study desk. The personality is disciplined yet inviting—clean, warm, and highly organized.

The aesthetic leans into **Modern Corporate** with **Minimalist** influences, utilizing high-quality serif typography for content to provide a scholarly rhythm. The interface prioritizes focus by reducing visual noise, using deep greens and warm ambers to create a grounded, studious atmosphere that differentiates itself from typical cold, clinical productivity tools.

## Colors
The palette is centered on a "Deep Forest" primary green, providing a sense of growth and stability. This is paired with "Warm Gold" accents for highlights and primary actions.

- **Backgrounds:** Use the warm off-white for light mode to reduce eye strain during long study sessions. In dark mode, a charcoal navy provides depth without being pitch black.
- **File Indicators:** Specific semantic colors are assigned to document types to allow for instant visual scanning of search results.
- **Shadow Tints:** All shadows in light mode must be tinted with a hint of the primary green or gold (#1B4332 at 5% opacity) rather than pure gray to maintain the "warm" brand promise.

## Typography
This design system employs a dual-font strategy to balance editorial elegance with functional clarity.

- **Source Serif 4:** Used for headings and primary content titles. Its scholarly character reinforces the academic context of the app.
- **Inter:** Used for all UI elements, labels, and metadata. Its high legibility ensures that complex organizational structures remain easy to navigate.
- **Hierarchy:** Maintain generous line height (1.5x for body text) to ensure readability during heavy research tasks.

## Layout & Spacing
The layout follows a **Fixed Grid** philosophy on desktop to mimic the boundaries of a physical notebook, transitioning to a fluid model on mobile devices.

- **Grid:** A 12-column grid is used for desktop (max-width 1280px) with 24px gutters.
- **Rhythm:** All vertical spacing must be a multiple of the 8px base unit.
- **Mobile:** On mobile, side margins shrink to 16px. Cards and content blocks should span the full width of the container minus the margins.
- **Density:** Use "Medium" density. Information should feel organized and spacious, never cramped.

## Elevation & Depth
Depth is conveyed through **Tonal Layers** and **Ambient Shadows**. 

- **Surface Tiers:** The background layer is the lowest. Cards and modals sit on the surface layer.
- **Shadows:** Use extremely soft, diffused shadows. The light mode shadow uses `box-shadow: 0 4px 20px rgba(27, 67, 50, 0.08)`. Avoid high-contrast black shadows.
- **Dark Mode Elevation:** In dark mode, depth is achieved by lightening the surface color (e.g., `#16213E`) against the deeper background (`#1A1A2E`), rather than using shadows.

## Shapes
The shape language is "Rounded-Soft," balancing the structure of a grid with the friendliness of organic curves.

- **Cards/Containers:** Use 16px (rounded-xl) for main content areas and cards to create a modern, approachable container.
- **Buttons:** Use a 24px radius (pill-shaped) for all primary and secondary buttons.
- **Input Fields:** Use 12px (rounded-lg) for form inputs and search bars to distinguish them from action buttons.

## Components
- **Buttons:** Primary buttons use the Forest Green background with white text. Hover states shift to the lighter green (#2D6A4F). Pill-shaped (24px) only.
- **Cards:** White background in light mode with a 1px border of #E5E7EB. On hover, the shadow should deepen slightly to indicate interactivity.
- **Search Bar:** A prominent, rounded-lg input with a "Warm Gold" focus ring. Use a 24px outlined search icon.
- **Chips/File Indicators:** Small, rounded-md (4px) labels. Each file type (PDF, DOCX, etc.) uses its assigned semantic color for the icon or a subtle 10% opacity background tint.
- **Lists:** Clean, spacious rows with 16px vertical padding. Use "Inter" Medium for titles and "Inter" Regular for secondary metadata.
- **Checkboxes:** Square with a 4px corner radius. When checked, use the Forest Green fill with a white checkmark.
- **Icons:** Use a consistent 24px size with an "Outlined" style and rounded terminals to match the font geometry.
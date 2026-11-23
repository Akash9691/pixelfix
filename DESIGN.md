# PixelFix design system

Generated with the open-source UI UX Pro Max skill (query: *mobile photo editing app, AI tools, dark creative/pro*), which recommended Inter + violet/cyan on a dark base. Final decisions below are implemented in `lib/core/theme/`.

| Token | Value |
|---|---|
| Background | `#0E0F13` (light: `#F6F6FA`) |
| Surfaces | `#17181D`, `#1F2128` |
| Accent | `#7C5CFF` electric violet |
| AI accent | `#22D3EE` cyan: only AI buttons and progress shimmer (gradient `accent → ai`) |
| Text | `#F4F5F8` / secondary `#A3A8B8` (≥ 7:1 on bg; ≥ 4.5:1 everywhere) |
| Border | 1 px, 8 % white, no heavy shadows |
| Radius | 16 px (cards, buttons), 20 px (sheets) |
| Spacing | 8-pt grid: 4 / 8 / 16 / 24 / 32 |
| Type (Inter, bundled, offline) | display 28, title 20, body 14, label 12 |
| Motion | 220 ms ease-out, no decorative animation |
| Touch targets | ≥ 48×48 dp, primary actions in the bottom 40 % |
| Icons | Material Symbols Rounded (built-in `Icons.*_rounded`) |

## Layout
Editor canvas ≈ 75 % of the screen; bottom tool rail + contextual panel. Flow for every AI tool: **select → preview → apply / cancel**; hold canvas to see the original.

## Accessibility
Semantic labels on icon buttons, contrast ≥ 4.5:1, layouts tested up to 1.3× font scale, haptics on tool switch and apply.

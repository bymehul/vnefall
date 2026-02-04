# VNEUI Roadmap

This roadmap focuses on building a flexible UI core that can power Vnefall menus now and grow into a reusable Odin UI toolkit later.

Status: Phases 0–5 are complete. The core UI set is done.

## Phase 0 — Foundations (Design)
- [x] Define a minimal public API and naming conventions
- [x] Choose style/theme data structures
- [x] Decide layout strategy (rows/columns + absolute)
- [x] Decide event/state model (hover/active/focus)

## Phase 1 — Core Primitives
- [x] Geometry: `rect`, `rounded_rect`, `border`, `line`
- [x] Text: `text`, `text_wrap`
- [x] Draw command list (backend-agnostic)
- [x] Hit testing and input capture

## Phase 2 — Layout + Theme
- [x] Layout containers: `row`, `column`, `stack`
- [x] Layout containers: `grid`
- [x] Spacing system: padding, gap
- [x] Theme system: colors, fonts, corner radius
- [x] Shadows
- [x] Per-widget style overrides

## Phase 3 — Essential Widgets
- [x] `label`
- [x] `button`
- [x] `toggle`
- [x] `slider`
- [x] `panel`
- [x] `scroll` (vertical, basic)

## Phase 4 — Game Menus (Vnefall)
- [x] Main menu
- [x] Preferences (volume, text speed, display)
- [x] Save/Load list UI
- [x] Confirmation dialogs

## Phase 5 — Advanced UI
- [x] Animated transitions
- [x] Modal stack and focus trapping
- [x] Tooltips
- [x] Toasts / notifications

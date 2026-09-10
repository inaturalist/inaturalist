# In-house component library

We are replacing jQuery UI widgets and react-bootstrap with components we own, built on
[react-aria](https://react-spectrum.adobe.com/react-aria/) + react-stately. react-aria gives us
hooks that return prop objects; the JSX, the class names and the CSS stay ours.

## Conventions

Components live in `app/webpack/shared/components/`, following the pattern set by
`carousel.tsx` / `tab_drawer.tsx`:

- TypeScript, functional, hooks.
- CSS Modules (`<name>.module.css`) — no new global stylesheet rules, no Bootstrap layout classes.
- A colocated `<name>.test.tsx` with jest + `@testing-library/react`, including a `jest-axe`
  assertion.
- New UI imports from `shared/components`, not from `react-bootstrap` and not via
  `.autocomplete( )` / `.dialog( )` on a jQuery object.

Both systems run side by side for the duration of the migration. A page may hold a new component
and a legacy jQuery UI widget at once.

## Status

| Component | react-aria hook | Replaces | Status |
|---|---|---|---|
| Combobox | `useComboBox` | `.autocomplete(` ×98 | `combobox.tsx`; first caller is the responsive observation-detail ID field |
| Popover / Tooltip | `usePopover`, `useTooltip` | `OverlayTrigger`, `Tooltip`, `Popover` ×44 | not started |
| Dialog | `useDialog` | `Modal` ×14, `.dialog(` ×23 | not started |
| Menu | `useMenu` | `Dropdown`/`MenuItem` ×22, `.menu(` ×7 | not started |
| Button / Badge / Panel / Icon | hand-written | `Button`, `Glyphicon`, `Badge`, `Panel` ×43 | not started |
| Slider | `useSlider` | `.slider(` ×22 | not started |
| DatePicker | `useDatePicker` | `.datepicker(` ×11 | not started |
| Tabs | `useTabs` | `.tabs(` ×4 | not started |
| Layout | CSS grid/flex | `Grid`/`Row`/`Col` ×142 | in flight on responsive branches |

## Combobox

`shared/components/combobox.tsx` is the generic field: a controlled input plus a listbox of
options supplied by the caller, who owns fetching.

- `onSearch( query )` fires debounced (`delay`, default 250ms) once the query reaches `minLength`
  (default 1). `minLength={0}` searches on focus with an empty query.
- `options` are `{ key, textValue, content }`; `content` is arbitrary JSX. `groups` render as
  listbox sections whose titles are headings — visible, but not options, so they are skipped by
  the arrow keys and excluded from the announced result count.
- The listbox lives in a `usePopover` overlay (`Overlay` + `DismissButton`, non-modal), so
  positioning, outside-press dismissal, and keeping DOM focus on the input while the listbox is
  scrolled/touched are react-aria's job — not ours. This is what fixes the mobile bug where
  scrolling the suggestions blurred the input and closed the list (WEB-1262).
- `header`, `message` and `footer` render outside the listbox — use them for loading and
  empty states and for controls like a "show more" toggle, which do not belong inside a listbox.
- `keepMenuOpenOnSelect` on an option keeps the menu up after it is chosen (react-aria otherwise
  closes on selection) — for rows that trigger a follow-up search rather than pick a value.
- Options must not contain focusable elements (WCAG: no nested interactive controls). A per-row
  link therefore has no home inside the listbox; put such affordances on the field instead.

`shared/components/taxon_combobox.tsx` builds the taxon field on it: computer-vision suggestions
for an empty query, taxon autocomplete for a typed one, an external-name-provider search, and a
hidden `taxon_id` input for non-React forms. The selection's thumbnail doubles as the link to its
taxon page — the per-result "view" link relocated out of the listbox to keep the options clean.

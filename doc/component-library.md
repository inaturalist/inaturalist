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
- `keepMenuOnBlur` leaves the menu up when the input loses focus, so a mobile keyboard dismissal
  does not take the results with it. Selecting an option or interacting outside the field still
  closes it.
- After a selection the field will not search again until the user types, so a filled-in name is
  not immediately searched back at them.
- `header`, `message` and `footer` render outside the listbox — use them for loading and
  empty states and for controls like a "show more" toggle, which do not belong inside a listbox.
- Options must not contain focusable elements (WCAG: no nested interactive controls).

`shared/components/taxon_combobox.tsx` builds the taxon field on it: computer-vision suggestions
for an empty query, taxon autocomplete for a typed one, an external-name-provider search, a
thumbnail of the selection, and a hidden `taxon_id` input for non-React forms.

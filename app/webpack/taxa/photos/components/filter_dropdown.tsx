import React from "react";
import { Dropdown, MenuItem } from "react-bootstrap";

export interface FilterOption {
  value: string | number;
  label: React.ReactNode;
}

interface FilterDropdownProps {
  id: string;
  label: React.ReactNode;
  onSelect: ( key: string | number ) => void;
  // The active option is the one whose value === selected. Callers pass their
  // "no selection" sentinel value (e.g. "any" / "none") rather than leaving it
  // undefined, so the sentinel lives with the caller that owns it.
  selected?: string | number;
  options: FilterOption[];
  // Optional override for the bold value in the toggle. When omitted it is
  // derived from the active option's label.
  display?: React.ReactNode;
}

const FilterDropdown = ( {
  id,
  label,
  onSelect,
  selected,
  options,
  display
}: FilterDropdownProps ) => {
  const resolvedDisplay = display
    ?? options.find( option => option.value === selected )?.label;
  return (
    <span className="control-group">
      <Dropdown id={id} onSelect={onSelect}>
        <Dropdown.Toggle bsStyle="link">
          { label }
          { ": " }
          <strong>{ resolvedDisplay }</strong>
        </Dropdown.Toggle>
        <Dropdown.Menu>
          { options.map( option => (
            <MenuItem
              key={`${id}-${option.value}`}
              eventKey={option.value}
              active={option.value === selected}
            >
              { option.label }
            </MenuItem>
          ) ) }
        </Dropdown.Menu>
      </Dropdown>
    </span>
  );
};

export default FilterDropdown;

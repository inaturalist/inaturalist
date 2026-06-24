import React from "react";
import { Dropdown, MenuItem } from "react-bootstrap";

export interface FilterOption {
  value: string | number;
  label: React.ReactNode;
}

interface Props {
  id: string;
  label: React.ReactNode;
  onSelect: ( key: unknown ) => void;
  selected?: string | number;
  options?: FilterOption[];
  // Optional override for the bold value in the toggle. When omitted it is
  // derived from the active option's label — pass it only when there are no
  // options to derive from (e.g. the children escape hatch).
  display?: React.ReactNode;
  children?: React.ReactNode;
}

const FilterDropdown = ( {
  id,
  label,
  onSelect,
  selected,
  options,
  display,
  children
}: Props ) => {
  const activeValue = selected ?? "any";
  const resolvedDisplay = display
    ?? options?.find( option => option.value === activeValue )?.label;
  return (
    <span className="control-group">
      <Dropdown id={id} onSelect={onSelect}>
        <Dropdown.Toggle bsStyle="link">
          { label }
          { ": " }
          <strong>{ resolvedDisplay }</strong>
        </Dropdown.Toggle>
        <Dropdown.Menu>
          { children ?? options?.map( option => (
            <MenuItem
              key={`${id}-${option.value}`}
              eventKey={option.value}
              active={option.value === activeValue}
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

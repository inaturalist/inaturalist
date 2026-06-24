import React from "react";
import { Dropdown, MenuItem } from "react-bootstrap";

export interface FilterOption {
  value: string | number;
  label: React.ReactNode;
}

interface Props {
  id: string;
  label: React.ReactNode;
  display: React.ReactNode;
  onSelect: ( key: unknown ) => void;
  selected?: string | number;
  options?: FilterOption[];
  children?: React.ReactNode;
}

const FilterDropdown = ( {
  id,
  label,
  display,
  onSelect,
  selected,
  options,
  children
}: Props ) => (
  <span className="control-group">
    <Dropdown id={id} onSelect={onSelect}>
      <Dropdown.Toggle bsStyle="link">
        { label }
        { ": " }
        <strong>{ display }</strong>
      </Dropdown.Toggle>
      <Dropdown.Menu>
        { children ?? options?.map( option => (
          <MenuItem
            key={`${id}-${option.value}`}
            eventKey={option.value}
            active={option.value === ( selected ?? "any" )}
          >
            { option.label }
          </MenuItem>
        ) ) }
      </Dropdown.Menu>
    </Dropdown>
  </span>
);

export default FilterDropdown;

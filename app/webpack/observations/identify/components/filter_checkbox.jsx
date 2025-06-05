import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import {
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import { isBlank } from "../../../shared/util";

const FilterCheckbox = ( {
  checked,
  className,
  defaultParams,
  disabled,
  label,
  noBlank,
  param,
  params,
  tipText,
  title,
  unchecked,
  updateSearchParams
} ) => {
  const checkedVal = ( checked || true ).toString( );
  const vals = _.has( params, param ) ? params[param].toString( ).split( "," ) : [];
  const thisValChecked = vals.indexOf( checkedVal ) >= 0;
  const cssClass = `FilterCheckbox checkbox ${className}`;
  let labelClass = "";
  if ( params[param] !== defaultParams[param] && thisValChecked ) {
    labelClass += " filter-changed";
  }
  let isDisabled = false;
  if (
    disabled
    || (
      noBlank
      && vals.length === 1
      && vals[0] === checkedVal
    )
  ) {
    isDisabled = true;
  }
  return (
    <div
      className={cssClass}
      key={`filters-${param}-${label}`}
    >
      <label className={labelClass} title={title}>
        <input
          type="checkbox"
          checked={thisValChecked}
          disabled={isDisabled}
          onChange={e => {
            let newVal = unchecked;
            let newVals = _.map( vals );
            if ( e.target.checked ) newVal = checkedVal;
            if ( isBlank( newVal ) ) {
              newVals = _.filter( vals, v => v !== checkedVal );
              updateSearchParams( { [param]: newVals.join( "," ) } );
            } else if ( !thisValChecked ) {
              newVals.push( newVal );
              updateSearchParams( { [param]: newVals.join( "," ) } );
            }
          }}
        />
        { " " }
        { label || I18n.t( param ) }
      </label>
      { tipText && (
        <OverlayTrigger
          trigger="click"
          placement="top"
          delayShow={1000}
          container={$( ".FiltersButtonContainer" ).get( 0 )}
          overlay={(
            <Tooltip id={`filter-checkbox-tooltip-${param}`}>
              {tipText}
            </Tooltip>
          )}
        >
          <button
            type="button"
            className="btn btn-nostyle"
            alt={I18n.t( "info" )}
          >
            <i className="fa fa-info-circle" />
          </button>
        </OverlayTrigger>
      ) }
    </div>
  );
};

FilterCheckbox.propTypes = {
  // The param value when the box is checked
  checked: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number
  ] ),
  className: PropTypes.string,
  defaultParams: PropTypes.object,
  disabled: PropTypes.bool,
  label: PropTypes.string,
  // Disable the input if no values for this param have been set
  noBlank: PropTypes.bool,
  // Name of the param this box controls
  param: PropTypes.string,
  // All the params that could be set
  params: PropTypes.object,
  // Tooltip text
  tipText: PropTypes.string,
  // Title attribute for the label element
  title: PropTypes.string,
  // The param value when the box is NOT checked
  unchecked: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number
  ] ),
  // Function to update the params with the new value of this input
  updateSearchParams: PropTypes.func
};

export default FilterCheckbox;

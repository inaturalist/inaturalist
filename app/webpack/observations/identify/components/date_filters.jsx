import React, { PropTypes } from "react";
import _ from "lodash";
import DateTimeFieldWrapper from "../../uploader/components/date_time_field_wrapper";
import JQueryUIMultiselect from "./jquery_ui_multiselect";

const DateFilters = ( {
  params,
  prefix,
  updateSearchParams
} ) => {
  const monthNames = ( "january february march april may june july august " +
      "september october november december" ).split( " " );
  let dateTypeField = "dateType";
  let onField = "on";
  let d1Field = "d1";
  let d2Field = "d2";
  let monthField = "month";
  if ( prefix ) {
    dateTypeField = `${prefix}DateType`;
    onField = `${prefix}_on`;
    d1Field = `${prefix}_d1`;
    d2Field = `${prefix}_d2`;
    monthField = `${prefix}_month`;
  }
  return (
    <div className="filters-dates">
      <label className="radio">
        <input
          type="radio"
          name={`${prefix}-date-type`}
          checked={ !params[dateTypeField] || params[dateTypeField] === "any" }
          onChange={ ( ) => {
            updateSearchParams( { [dateTypeField]: "any" } );
          } }
        />
        { _.capitalize( I18n.t( "any" ) ) }
      </label>
      <label className="radio">
        <input
          type="radio"
          name={`${prefix}-date-type`}
          value="exact"
          checked={ params[dateTypeField] === "exact" }
          onChange={ e => updateSearchParams( { [dateTypeField]: e.target.value } ) }
        />
        <span className="date-type date-type-exact">
          { I18n.t( "exact_date" ) }
          <div
            style={ { position: "relative" }}
            className={ params[dateTypeField] === "exact" ? "" : "collapse"}
          >
            <DateTimeFieldWrapper
              mode="date"
              className={
                "filters-dates-exact form-control input-sm date-picker" +
                `${params[onField] ? "filter-changed" : ""}`
              }
              inputFormat="YYYY-MM-DD"
              defaultText={ params[onField] || "YYYY-MM-DD" }
              onClick={ ( ) => updateSearchParams( { [dateTypeField]: "exact" } ) }
              onChange={ date => updateSearchParams( { [onField]: date } ) }
            />
          </div>
        </span>
      </label>
      <label className="radio">
        <input
          type="radio"
          name={`${prefix}-date-type`}
          value="range"
          checked={ params[dateTypeField] === "range" }
          onChange={ e => updateSearchParams( { [dateTypeField]: e.target.value } ) }
        />
        <span className="date-type date-type-range">
          { I18n.t( "range" ) }
          <div
            style={ { position: "relative" } }
            className={ `stacked ${params[dateTypeField] === "range" ? "" : "collapse"}` }
          >
            <DateTimeFieldWrapper
              mode="date"
              className={
                "filters-dates-exact form-control input-sm date-picker" +
                `${params[d1Field] ? "filter-changed" : ""}`
              }
              inputFormat="YYYY-MM-DD"
              defaultText={ I18n.t( "start" ) }
              onClick={ ( ) => updateSearchParams( { [dateTypeField]: "exact" } ) }
              onChange={ date => updateSearchParams( { [d1Field]: date } ) }
            />
          </div>
          <div
            style={ { position: "relative" } }
            className={ params[dateTypeField] === "range" ? "" : "collapse"}
          >
            <DateTimeFieldWrapper
              mode="date"
              className={
                "filters-dates-exact form-control input-sm date-picker" +
                `${params[d2Field] ? "filter-changed" : ""}`
              }
              inputFormat="YYYY-MM-DD"
              defaultText={ I18n.t( "end" ) }
              onClick={ ( ) => updateSearchParams( { [dateTypeField]: "exact" } ) }
              onChange={ date => updateSearchParams( { [d2Field]: date } ) }
            />
          </div>
        </span>
      </label>
      <label className="radio">
        <input
          type="radio"
          name={`${prefix}-date-type`}
          value="month"
          checked={ params[dateTypeField] === "month" }
          onChange={ e => updateSearchParams( { [dateTypeField]: e.target.value } ) }
        />
        <span className="date-type date-type-month">
          { I18n.t( "months" ) }
          <div
            style={ { position: "relative" } }
            className={ params[dateTypeField] === "month" ? "" : "collapse"}
          >
            <JQueryUIMultiselect
              className={`form-control input-sm ${params[monthField] ? "filter-changed" : ""}`}
              id="filters-dates-month"
              onOpen={ ( ) => updateSearchParams( { [dateTypeField]: "month" } ) }
              onChange={ values => {
                updateSearchParams( { [monthField]: values } );
              } }
              defaultValue={params[monthField] || []}
              data={
                _.map( monthNames, ( month, i ) => (
                  {
                    value: i + 1,
                    label: I18n.t( `date_format.month.${month}` )
                  }
                ) )
              }
            />
          </div>
        </span>
      </label>
    </div>
  );
};

DateFilters.propTypes = {
  params: PropTypes.object.isRequired,
  prefix: PropTypes.string,
  updateSearchParams: PropTypes.func.isRequired
};

export default DateFilters;

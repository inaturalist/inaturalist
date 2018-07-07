import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import moment from "moment-timezone";

const FormattedDate = ( { date, time, timezone } ) => {
  let dateString;
  let timeString;
  if ( _.isEmpty( date ) ) {
    dateString = I18n.t( "unknown" );
  } else {
    const dateObject = moment( date );
    const now = moment( new Date( ) );
    if ( dateObject.isSame( now, "day" ) ) {
      dateString = I18n.t( "today" );
    } else if ( dateObject.isSame( now.subtract( 1, "day" ), "day" ) ) {
      dateString = I18n.t( "yesterday" );
    } else {
      dateString = dateObject.format( "ll" );
    }
    if ( !_.isEmpty( time ) ) {
      timeString = moment( time ).tz( timezone || "UTC" ).format( "LT z" );
    }
  }
  return (
    <span className="FormattedDate">
      <span className="date">{ dateString }</span>
      { timeString && ( <span className="time">{ timeString }</span> ) }
    </span>
  );
};

FormattedDate.propTypes = {
  date: PropTypes.string,
  time: PropTypes.string,
  timezone: PropTypes.string
};

export default FormattedDate;

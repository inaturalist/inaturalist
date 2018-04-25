import _ from "lodash";
import moment from "moment-timezone";
/* global TIMEZONE */

const util = class util {
  static momentDateFromString( dateString ) {
    if ( !dateString ) { return null; }
    const trimmedDateString = dateString.trim( );
    if ( _.isEmpty( trimmedDateString ) ) { return null; }
    if ( trimmedDateString.match( /^\d{4}-\d{1,2}-\d{1,2} \d{1,2}:\d{2} [+-]\d{1,2}:\d{2}/ ) ) {
      return moment( trimmedDateString, "YYYY-MM-DD HH:mm Z" ).parseZone( ).tz( TIMEZONE );
    }
    return moment( trimmedDateString );
  }

  static isDate( dateString ) {
    if ( !dateString ) { return null; }
    return !!dateString.match( /^\d{4}-\d{1,2}-\d{1,2}$/ );
  }
};

export default util;

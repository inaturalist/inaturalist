import moment from "moment-timezone";
/* global TIMEZONE */

const util = class util {
  static momentDateFromString( dateString ) {
    if ( !dateString ) { return null; }
    if ( dateString.match( /^\d{4}-\d{1,2}-\d{1,2} \d{1,2}:\d{2} [+-]\d{1,2}:\d{2}/ ) ) {
      return moment( dateString, "YYYY-MM-DD HH:mm Z" ).parseZone( ).tz( TIMEZONE );
    }
    return moment( dateString );
  }

  static isDate( dateString ) {
    if ( !dateString ) { return null; }
    return !!dateString.match( /^\d{4}-\d{1,2}-\d{1,2}$/ );
  }
};

export default util;

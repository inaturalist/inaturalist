import _ from "lodash";
import moment from "moment";
import { photoTimeMs } from "../../../shared/geotrack";
import { parsableDatetimeFormat } from "./util";

// Uploader glue for the geotrack library: turns obs cards and their files
// into the { id, timeMs } items geotrack's matchMany expects

export function browserTimeZone( ) {
  try {
    return Intl.DateTimeFormat( ).resolvedOptions( ).timeZone;
  } catch ( e ) {
    return null;
  }
}

// When the card's photo was taken as UTC ms, or null. EXIF details (seconds,
// UTC offset, GPS stamp) win unless the user has changed the card's date.
export function cardTimeMs( card, files, { timeZone, clockOffsetMs = 0 } = {} ) {
  const exifFile = _.find( files, f => f.cardID === card.id && f.metadata?.exifDateTime );
  if ( exifFile && ( !card.date || card.date === exifFile.metadata.date ) ) {
    const resolved = photoTimeMs( {
      dateTime: exifFile.metadata.exifDateTime,
      offset: exifFile.metadata.exifOffset,
      gpsDateTime: exifFile.metadata.gpsDateTime,
      timeZone,
      clockOffsetMs
    } );
    if ( resolved ) return resolved.timeMs;
  }
  if ( card.date ) {
    const m = moment( card.date, parsableDatetimeFormat( ) );
    if ( m.isValid( ) ) {
      const resolved = photoTimeMs( {
        dateTime: m.format( "YYYY-MM-DD HH:mm:ss" ),
        timeZone,
        clockOffsetMs
      } );
      if ( resolved ) return resolved.timeMs;
    }
  }
  return null;
}

export function cardTimeItems( obsCards, files, options = {} ) {
  return _.compact( _.map( obsCards, card => {
    const timeMs = cardTimeMs( card, files, options );
    return timeMs === null ? null : { id: card.id, timeMs };
  } ) );
}

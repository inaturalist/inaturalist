import _ from "lodash";
import moment from "moment";
import { DEFAULT_MATCH_OPTIONS, photoTimeMs } from "../../../shared/geotrack";
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

// How many items fall within an activity, allowing for the matcher's
// extrapolation window at either end
export function countItemsDuringActivity(
  items,
  activity,
  marginMs = DEFAULT_MATCH_OPTIONS.maxExtrapolationMs
) {
  if ( !Number.isFinite( activity.startTimeMs ) ) return 0;
  const startMs = activity.startTimeMs - marginMs;
  const endMs = activity.startTimeMs + ( activity.durationMs || 0 ) + marginMs;
  return items.filter( ( { timeMs } ) => timeMs >= startMs && timeMs <= endMs ).length;
}

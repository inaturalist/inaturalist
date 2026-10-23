// Resolving when a photo was taken, as UTC epoch ms. Track points are UTC but
// EXIF DateTimeOriginal is wall-clock time with no zone, so we need an offset
// from somewhere: the EXIF OffsetTimeOriginal tag, the GPS UTC stamp, or a
// time zone supplied by the caller (in that order of preference).

const DATETIME_PATTERN = /^(\d{4})[:\-/](\d{2})[:\-/](\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?/;
const OFFSET_PATTERN = /^([+-])(\d{2}):?(\d{2})$/;

// Parses "YYYY:MM:DD HH:mm:ss" (EXIF) or "YYYY-MM-DD HH:mm[:ss]" into ms as
// if the wall-clock time were UTC
export function parseWallClock( str ) {
  const m = DATETIME_PATTERN.exec( ( str || "" ).trim( ) );
  if ( !m ) return null;
  const [, y, mo, d, h, mi, s] = m.map( Number );
  const ms = Date.UTC( y, mo - 1, d, h, mi, s || 0 );
  return Number.isFinite( ms ) ? ms : null;
}

// "+09:00", "-0700" or "Z" into minutes east of UTC
export function parseUtcOffset( str ) {
  const trimmed = ( str || "" ).trim( );
  if ( trimmed === "Z" ) return 0;
  const m = OFFSET_PATTERN.exec( trimmed );
  if ( !m ) return null;
  const minutes = Number( m[2] ) * 60 + Number( m[3] );
  return m[1] === "-" ? -minutes : minutes;
}

// Minutes east of UTC for an IANA time zone at a given instant
export function zoneOffsetMinutes( utcMs, timeZone ) {
  const parts = new Intl.DateTimeFormat( "en-US", {
    timeZone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit"
  } ).formatToParts( new Date( utcMs ) );
  const get = type => Number( parts.find( p => p.type === type ).value );
  const asUtc = Date.UTC( get( "year" ), get( "month" ) - 1, get( "day" ), get( "hour" ), get( "minute" ), get( "second" ) );
  return Math.round( ( asUtc - Math.floor( utcMs / 1000 ) * 1000 ) / 60000 );
}

// Wall-clock ms (from parseWallClock) in a time zone into UTC ms. The second
// pass corrects the offset when the first guess lands across a DST change.
export function wallClockToUtcMs( wallMs, timeZone ) {
  const firstGuess = wallMs - zoneOffsetMinutes( wallMs, timeZone ) * 60000;
  return wallMs - zoneOffsetMinutes( firstGuess, timeZone ) * 60000;
}

// Returns { timeMs, basis } where basis is "offset", "gps" or "zone", or null
// if there isn't enough information. clockOffsetMs corrects a camera clock
// that was set wrong, so it is not applied to GPS stamps.
export function photoTimeMs( {
  dateTime,
  offset,
  gpsDateTime,
  timeZone,
  clockOffsetMs = 0
} = {} ) {
  const wallMs = parseWallClock( dateTime );
  const offsetMinutes = parseUtcOffset( offset );
  if ( wallMs !== null && offsetMinutes !== null ) {
    return { timeMs: wallMs - offsetMinutes * 60000 + clockOffsetMs, basis: "offset" };
  }
  const gpsMs = parseWallClock( gpsDateTime );
  if ( gpsMs !== null ) {
    return { timeMs: gpsMs, basis: "gps" };
  }
  if ( wallMs !== null && timeZone ) {
    try {
      return { timeMs: wallClockToUtcMs( wallMs, timeZone ) + clockOffsetMs, basis: "zone" };
    } catch ( e ) {
      // Unknown time zone name
      return null;
    }
  }
  return null;
}

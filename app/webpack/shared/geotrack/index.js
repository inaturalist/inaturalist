// geotrack: parse GPS tracks from various sources and match photo times to
// locations along them. Kept free of app, DOM-global, google.maps and moment
// dependencies so it can move to its own package and be shared with the
// mobile app and the API. Do not import application code from here.

import fromFit from "./adapters/fit";
import fromGpx from "./adapters/gpx";
import fromStravaStreams from "./adapters/strava";
import fromTcx from "./adapters/tcx";

export {
  fromFit,
  fromGpx,
  fromStravaStreams,
  fromTcx
};
export { computeBounds, normalizeTrack } from "./track";
export { DEFAULT_MATCH_OPTIONS, matchMany, matchTime } from "./match";
export { photoTimeMs } from "./time";

export const TRACK_FORMATS = {
  gpx: { extension: ".gpx", binary: false },
  tcx: { extension: ".tcx", binary: false },
  fit: { extension: ".fit", binary: true }
};

export const TRACK_FILE_EXTENSIONS = Object.values( TRACK_FORMATS ).map( f => f.extension );

export function trackFormatFromFileName( fileName ) {
  const lower = ( fileName || "" ).toLowerCase( );
  return Object.keys( TRACK_FORMATS ).find( format => (
    lower.endsWith( TRACK_FORMATS[format].extension )
  ) ) || null;
}

// content is a string for XML formats and an ArrayBuffer for binary ones.
// Always returns a Promise of a Track.
export async function parseTrack( content, format, options = {} ) {
  switch ( format ) {
    case "gpx": return fromGpx( content, options );
    case "tcx": return fromTcx( content, options );
    case "fit": return fromFit( content );
    default: throw new Error( `Unsupported track format: ${format}` );
  }
}

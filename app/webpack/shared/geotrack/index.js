// geotrack: parse GPS tracks from various sources and match photo times to
// locations along them. Kept free of app, DOM-global, google.maps and moment
// dependencies so it can move to its own package and be shared with the
// mobile app and the API. Do not import application code from here.

import fromFit from "./adapters/fit";
import fromGpx from "./adapters/gpx";
import fromStravaStreams from "./adapters/strava";
import fromTcx from "./adapters/tcx";
import { TRACK_FORMATS, TRACK_FILE_EXTENSIONS, trackFormatFromFileName } from "./formats";

export {
  fromFit,
  fromGpx,
  fromStravaStreams,
  fromTcx
};
export { computeBounds, normalizeTrack } from "./track";
export { DEFAULT_MATCH_OPTIONS, matchMany, matchTime } from "./match";
export { photoTimeMs } from "./time";
export {
  downloadGarminActivityFile,
  exchangeGarminApiKey,
  GARMIN_API_KEY_SETTINGS_URL,
  GARMIN_PERSONAL_API_URL,
  GarminApiError,
  garminTokenExpired,
  normalizeGarminActivity,
  searchGarminActivities
} from "./sources/garmin";
export { TRACK_FORMATS, TRACK_FILE_EXTENSIONS, trackFormatFromFileName };

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

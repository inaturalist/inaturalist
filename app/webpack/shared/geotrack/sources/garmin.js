// Garmin Connect Personal API: a user creates an API key in Garmin Connect
// settings and exchanges it for a 24-hour access token (a JWT). There are no
// refresh tokens; exchange the key again when the token expires.
// https://developer.garmin.com/gc-developer-program/overview/
//
// Garmin answers every CORS preflight with 403, so web pages must reach it
// through a relay passed as options.baseUrl. React Native and Node can call it
// directly. Every function takes options.fetch for platforms or tests that
// need their own.

import { TRACK_FORMATS, trackFormatFromFileName } from "../formats";
import { extractFirstFile } from "../zip";

export const GARMIN_PERSONAL_API_URL = "https://personal.connectapi.garmin.com";
export const GARMIN_API_KEY_SETTINGS_URL = "https://connect.garmin.com/app/settings/personalApiToken";

const TOKEN_PATH = "/personalapitoken-service/personal-api/personal-api-key/token";
const ACTIVITIES_PATH = "/activitylist-service/activities/search/activities";
const DOWNLOAD_PATH = "/download-service/files/activity";
// Garmin's search fails with HTTP 500 for pages larger than about 45
const MAX_ACTIVITY_PAGE_SIZE = 45;
const FALLBACK_TOKEN_LIFETIME_MS = 24 * 60 * 60 * 1000;
const TOKEN_EXPIRY_MARGIN_MS = 5 * 60 * 1000;

export class GarminApiError extends Error {
  constructor( message, status = null ) {
    super( message );
    this.name = "GarminApiError";
    this.status = status;
  }

  // The key or token was rejected: mistyped, expired or revoked
  get unauthorized( ) {
    return this.status === 401 || this.status === 403;
  }
}

async function request( path, { method = "GET", headers, params } = {}, options = {} ) {
  const fetchFn = options.fetch || ( ( url, init ) => fetch( url, init ) );
  const baseUrl = ( options.baseUrl || GARMIN_PERSONAL_API_URL ).replace( /\/+$/, "" );
  const query = params ? new URLSearchParams( params ).toString( ) : "";
  let response;
  try {
    response = await fetchFn( `${baseUrl}${path}${query ? `?${query}` : ""}`, { method, headers } );
  } catch ( e ) {
    throw new GarminApiError( `Could not reach Garmin: ${e.message}` );
  }
  if ( !response.ok ) {
    throw new GarminApiError( `Garmin request failed with HTTP ${response.status}`, response.status );
  }
  return response;
}

function base64UrlDecode( str ) {
  const base64 = str.replace( /-/g, "+" ).replace( /_/g, "/" );
  return atob( base64 + "=".repeat( ( 4 - ( base64.length % 4 ) ) % 4 ) );
}

// The JWT's exp claim, unverified; only used to know when to exchange again
function jwtExpiryMs( token ) {
  const parts = token.split( "." );
  if ( parts.length !== 3 ) return null;
  try {
    const { exp } = JSON.parse( base64UrlDecode( parts[1] ) );
    return Number.isFinite( exp ) ? exp * 1000 : null;
  } catch ( e ) {
    return null;
  }
}

// Returns { accessToken, expiresAtMs }
export async function exchangeGarminApiKey( apiKey, options = {} ) {
  const key = ( apiKey || "" ).trim( );
  if ( !key ) throw new GarminApiError( "Missing Garmin API key" );
  const response = await request( TOKEN_PATH, {
    method: "POST",
    headers: { Authorization: `ApiKey ${key}`, Accept: "*/*" }
  }, options );
  const accessToken = ( await response.text( ) ).trim( ).replace( /^"|"$/g, "" );
  if ( !accessToken ) throw new GarminApiError( "Garmin returned an empty token" );
  const nowMs = options.nowMs ?? Date.now( );
  return {
    accessToken,
    expiresAtMs: jwtExpiryMs( accessToken ) ?? nowMs + FALLBACK_TOKEN_LIFETIME_MS
  };
}

export function garminTokenExpired( token, nowMs = Date.now( ) ) {
  return !token || !token.accessToken
    || token.expiresAtMs - nowMs <= TOKEN_EXPIRY_MARGIN_MS;
}

// Garmin reports GMT times as "YYYY-MM-DD HH:mm:ss" without a zone
function parseGmt( str ) {
  if ( !str ) return NaN;
  return Date.parse( `${str.replace( " ", "T" )}Z` );
}

export function normalizeGarminActivity( raw ) {
  const durationS = raw.elapsedDuration ?? raw.duration;
  return {
    id: raw.activityId,
    name: raw.activityName || "",
    type: raw.activityType?.typeKey || null,
    startTimeMs: parseGmt( raw.startTimeGMT ),
    durationMs: Number.isFinite( durationS ) ? durationS * 1000 : null,
    distanceM: Number.isFinite( raw.distance ) ? raw.distance : null,
    // Indoor activities have no GPS track
    hasTrack: raw.hasPolyline ?? Number.isFinite( raw.startLatitude )
  };
}

function bearer( token ) {
  const accessToken = typeof token === "string" ? token : token?.accessToken;
  if ( !accessToken ) throw new GarminApiError( "Missing Garmin access token" );
  return `Bearer ${accessToken}`;
}

// Most recent first. options: start, limit, startDate and endDate
// ("YYYY-MM-DD", the activity's local date)
export async function searchGarminActivities( token, options = {} ) {
  const params = {
    start: String( options.start || 0 ),
    limit: String( Math.min( options.limit || 20, MAX_ACTIVITY_PAGE_SIZE ) )
  };
  if ( options.startDate ) params.startDate = options.startDate;
  if ( options.endDate ) params.endDate = options.endDate;
  const response = await request( ACTIVITIES_PATH, {
    headers: { Authorization: bearer( token ), Accept: "application/json" },
    params
  }, options );
  const activities = await response.json( );
  return Array.isArray( activities ) ? activities.map( normalizeGarminActivity ) : [];
}

// The activity's original upload (usually FIT). Returns { fileName, format,
// content }, with content ready for parseTrack. options.inflateRaw is passed
// to the zip reader.
export async function downloadGarminActivityFile( token, activityId, options = {} ) {
  const id = Number( activityId );
  if ( !Number.isSafeInteger( id ) || id <= 0 ) {
    throw new GarminApiError( `Invalid Garmin activity id: ${activityId}` );
  }
  const response = await request( `${DOWNLOAD_PATH}/${id}`, {
    headers: { Authorization: bearer( token ), Accept: "application/x-zip-compressed" }
  }, options );
  let file;
  try {
    file = await extractFirstFile( await response.arrayBuffer( ), options );
  } catch ( e ) {
    throw new GarminApiError( `Could not read the Garmin download: ${e.message}` );
  }
  const format = trackFormatFromFileName( file.name );
  if ( !format ) throw new GarminApiError( `Unsupported Garmin activity file: ${file.name}` );
  const { bytes } = file;
  const content = TRACK_FORMATS[format].binary
    ? bytes.buffer.slice( bytes.byteOffset, bytes.byteOffset + bytes.byteLength )
    : new TextDecoder( ).decode( bytes );
  return { fileName: file.name, format, content };
}

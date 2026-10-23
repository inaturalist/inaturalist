import { normalizeTrack } from "../track";

// Strava's GET /activities/{id}/streams?keys=latlng,time&key_by_type=true
// response. The time stream is seconds since the activity's start_date.
export default function fromStravaStreams( streams, startDate, name = "" ) {
  const latlng = ( streams && streams.latlng && streams.latlng.data ) || [];
  const seconds = ( streams && streams.time && streams.time.data ) || [];
  const startMs = Date.parse( startDate );
  const points = latlng.map( ( [lat, lng], i ) => ( {
    lat,
    lng,
    timeMs: startMs + seconds[i] * 1000
  } ) );
  return normalizeTrack( { source: "strava", name, points } );
}

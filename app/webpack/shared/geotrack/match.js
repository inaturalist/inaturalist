import { distanceM, interpolate } from "./geo";

export const DEFAULT_MATCH_OPTIONS = {
  // How far before the first / after the last point we still trust the track
  maxExtrapolationMs: 30 * 60 * 1000,
  // Larger gaps between points are treated as a paused recording, not as
  // continuous movement, so we don't interpolate across them
  maxGapMs: 30 * 60 * 1000,
  // Floor for the reported accuracy; a track point is never a perfect fix
  minAccuracyM: 10
};

function result( point, method, accuracyM, opts ) {
  return {
    lat: point.lat,
    lng: point.lng,
    accuracyM: Math.max( opts.minAccuracyM, Math.round( accuracyM ) ),
    method
  };
}

// Index of the first point whose time is >= timeMs
function lowerBound( points, timeMs ) {
  let lo = 0;
  let hi = points.length;
  while ( lo < hi ) {
    const mid = Math.floor( ( lo + hi ) / 2 );
    if ( points[mid].timeMs < timeMs ) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

// Returns { lat, lng, accuracyM, method } where method is "exact",
// "interpolated" or "clamped", or null if the time isn't covered by the track
export function matchTime( timeMs, track, options = {} ) {
  const opts = { ...DEFAULT_MATCH_OPTIONS, ...options };
  const points = track && track.points;
  if ( !Number.isFinite( timeMs ) || !points || points.length === 0 ) return null;

  const first = points[0];
  const last = points[points.length - 1];
  if ( timeMs < first.timeMs ) {
    return first.timeMs - timeMs <= opts.maxExtrapolationMs
      ? result( first, "clamped", 0, opts )
      : null;
  }
  if ( timeMs > last.timeMs ) {
    return timeMs - last.timeMs <= opts.maxExtrapolationMs
      ? result( last, "clamped", 0, opts )
      : null;
  }

  const idx = lowerBound( points, timeMs );
  const after = points[idx];
  if ( after.timeMs === timeMs ) return result( after, "exact", 0, opts );

  const before = points[idx - 1];
  const gapMs = after.timeMs - before.timeMs;
  if ( gapMs > opts.maxGapMs ) {
    const sinceBefore = timeMs - before.timeMs;
    const untilAfter = after.timeMs - timeMs;
    const nearest = sinceBefore <= untilAfter ? before : after;
    return Math.min( sinceBefore, untilAfter ) <= opts.maxExtrapolationMs
      ? result( nearest, "clamped", 0, opts )
      : null;
  }

  const fraction = ( timeMs - before.timeMs ) / gapMs;
  return result(
    interpolate( before, after, fraction ),
    "interpolated",
    distanceM( before, after ) / 2,
    opts
  );
}

// items: [{ id, timeMs }]. Returns { [id]: match } for items that matched.
export function matchMany( items, track, options = {} ) {
  const matches = {};
  ( items || [] ).forEach( item => {
    const match = matchTime( item.timeMs, track, options );
    if ( match ) matches[item.id] = match;
  } );
  return matches;
}

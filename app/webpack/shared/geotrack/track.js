// A Track is the format-independent shape every adapter produces:
// { source, name, points: [{ lat, lng, timeMs, ele? }] }, sorted by timeMs.
// Points without a valid time or coordinates are dropped because they can't
// be matched against a photo's timestamp.

function validPoint( pt ) {
  return pt
    && Number.isFinite( pt.lat ) && Number.isFinite( pt.lng )
    && Math.abs( pt.lat ) <= 90 && Math.abs( pt.lng ) <= 180
    && Number.isFinite( pt.timeMs );
}

export function normalizeTrack( { source, name, points } ) {
  const cleaned = ( points || [] ).filter( validPoint ).map( pt => {
    const point = { lat: pt.lat, lng: pt.lng, timeMs: pt.timeMs };
    if ( Number.isFinite( pt.ele ) ) point.ele = pt.ele;
    return point;
  } );
  cleaned.sort( ( a, b ) => a.timeMs - b.timeMs );
  return { source, name: name || "", points: cleaned };
}

export function computeBounds( points ) {
  if ( !points || points.length === 0 ) return null;
  let north = -Infinity;
  let south = Infinity;
  let east = -Infinity;
  let west = Infinity;
  points.forEach( pt => {
    if ( pt.lat > north ) north = pt.lat;
    if ( pt.lat < south ) south = pt.lat;
    if ( pt.lng > east ) east = pt.lng;
    if ( pt.lng < west ) west = pt.lng;
  } );
  return {
    north,
    south,
    east,
    west
  };
}

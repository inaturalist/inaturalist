// Spherical helpers so matching works without google.maps.geometry

const EARTH_RADIUS_M = 6371008.8;
const toRad = deg => ( deg * Math.PI ) / 180;
const toDeg = rad => ( rad * 180 ) / Math.PI;

export function distanceM( a, b ) {
  const dLat = toRad( b.lat - a.lat );
  const dLng = toRad( b.lng - a.lng );
  const h = Math.sin( dLat / 2 ) ** 2
    + Math.cos( toRad( a.lat ) ) * Math.cos( toRad( b.lat ) ) * Math.sin( dLng / 2 ) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin( Math.min( 1, Math.sqrt( h ) ) );
}

// Great-circle interpolation, so segments crossing the antimeridian stay sane
export function interpolate( a, b, fraction ) {
  const lat1 = toRad( a.lat );
  const lng1 = toRad( a.lng );
  const lat2 = toRad( b.lat );
  const lng2 = toRad( b.lng );
  const angle = distanceM( a, b ) / EARTH_RADIUS_M;
  if ( angle === 0 ) return { lat: a.lat, lng: a.lng };
  const sinAngle = Math.sin( angle );
  const wa = Math.sin( ( 1 - fraction ) * angle ) / sinAngle;
  const wb = Math.sin( fraction * angle ) / sinAngle;
  const x = wa * Math.cos( lat1 ) * Math.cos( lng1 ) + wb * Math.cos( lat2 ) * Math.cos( lng2 );
  const y = wa * Math.cos( lat1 ) * Math.sin( lng1 ) + wb * Math.cos( lat2 ) * Math.sin( lng2 );
  const z = wa * Math.sin( lat1 ) + wb * Math.sin( lat2 );
  return {
    lat: toDeg( Math.atan2( z, Math.sqrt( x * x + y * y ) ) ),
    lng: toDeg( Math.atan2( y, x ) )
  };
}

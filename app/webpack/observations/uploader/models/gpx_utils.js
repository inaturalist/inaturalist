import moment from "moment";
import { parsableDatetimeFormat } from "./util";

const MAX_EXTRAPOLATION_MS = 30 * 60 * 1000; // 30 minutes

export function parseGpx( xmlString ) {
  const parser = new DOMParser();
  const doc = parser.parseFromString( xmlString, "application/xml" );
  const parserError = doc.querySelector( "parsererror" );
  if ( parserError ) {
    throw new Error( "Invalid GPX file" );
  }

  const tracks = [];
  doc.querySelectorAll( "trk" ).forEach( trk => {
    const nameEl = trk.querySelector( "name" );
    const name = nameEl ? nameEl.textContent : "";
    const points = [];
    trk.querySelectorAll( "trkpt" ).forEach( pt => {
      const lat = parseFloat( pt.getAttribute( "lat" ) );
      const lng = parseFloat( pt.getAttribute( "lon" ) );
      if ( isNaN( lat ) || isNaN( lng ) ) return;
      if ( Math.abs( lat ) > 90 || Math.abs( lng ) > 180 ) return;
      const timeEl = pt.querySelector( "time" );
      const time = timeEl ? new Date( timeEl.textContent ) : null;
      points.push( { lat, lng, time } );
    } );
    tracks.push( { name, points } );
  } );

  return { tracks };
}

export function flattenTrackPoints( parsedGpx ) {
  const allPoints = [];
  parsedGpx.tracks.forEach( track => {
    track.points.forEach( pt => {
      if ( pt.time && !isNaN( pt.time.getTime() ) ) {
        allPoints.push( pt );
      }
    } );
  } );
  allPoints.sort( ( a, b ) => a.time.getTime() - b.time.getTime() );
  return allPoints;
}

export function computeBounds( points ) {
  if ( points.length === 0 ) return null;
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
  return { north, south, east, west };
}

function binarySearchTrackpoints( sortedPoints, timestampMs ) {
  let lo = 0;
  let hi = sortedPoints.length - 1;
  while ( lo < hi ) {
    const mid = Math.floor( ( lo + hi ) / 2 );
    if ( sortedPoints[mid].time.getTime() < timestampMs ) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

export function matchTimestampToTrack( timestampMs, sortedPoints ) {
  if ( !sortedPoints || sortedPoints.length === 0 || timestampMs == null ) {
    return null;
  }

  if ( sortedPoints.length === 1 ) {
    const diff = Math.abs( timestampMs - sortedPoints[0].time.getTime() );
    if ( diff > MAX_EXTRAPOLATION_MS ) return null;
    return { lat: sortedPoints[0].lat, lng: sortedPoints[0].lng, accuracy: 0 };
  }

  const firstTime = sortedPoints[0].time.getTime();
  const lastTime = sortedPoints[sortedPoints.length - 1].time.getTime();

  // Before first point
  if ( timestampMs < firstTime ) {
    if ( firstTime - timestampMs > MAX_EXTRAPOLATION_MS ) return null;
    return { lat: sortedPoints[0].lat, lng: sortedPoints[0].lng, accuracy: 0 };
  }

  // After last point
  if ( timestampMs > lastTime ) {
    if ( timestampMs - lastTime > MAX_EXTRAPOLATION_MS ) return null;
    const last = sortedPoints[sortedPoints.length - 1];
    return { lat: last.lat, lng: last.lng, accuracy: 0 };
  }

  const idx = binarySearchTrackpoints( sortedPoints, timestampMs );

  // Exact match
  if ( sortedPoints[idx].time.getTime() === timestampMs ) {
    return {
      lat: sortedPoints[idx].lat,
      lng: sortedPoints[idx].lng,
      accuracy: 0
    };
  }

  const before = sortedPoints[idx - 1];
  const after = sortedPoints[idx];
  const timeDelta = after.time.getTime() - before.time.getTime();
  const fraction = timeDelta > 0
    ? ( timestampMs - before.time.getTime() ) / timeDelta
    : 0;

  if ( typeof google !== "undefined" && google.maps && google.maps.geometry ) {
    const ptBefore = new google.maps.LatLng( before.lat, before.lng );
    const ptAfter = new google.maps.LatLng( after.lat, after.lng );
    const interpolated = google.maps.geometry.spherical.interpolate(
      ptBefore, ptAfter, fraction
    );
    const distance = google.maps.geometry.spherical.computeDistanceBetween(
      ptBefore, ptAfter
    );
    return {
      lat: interpolated.lat(),
      lng: interpolated.lng(),
      accuracy: Math.round( distance / 2 )
    };
  }

  // Fallback: linear interpolation without Google Maps
  return {
    lat: before.lat + fraction * ( after.lat - before.lat ),
    lng: before.lng + fraction * ( after.lng - before.lng ),
    accuracy: 0
  };
}

function getCardTimestampMs( card, files ) {
  const cardFiles = Object.values( files ).filter( f => f.cardID === card.id );
  for ( const file of cardFiles ) {
    if ( file.metadata && file.metadata.date ) {
      const m = moment( file.metadata.date, parsableDatetimeFormat() );
      if ( m.isValid() ) return m.valueOf();
    }
  }
  if ( card.date ) {
    const m = moment( card.date, parsableDatetimeFormat() );
    if ( m.isValid() ) return m.valueOf();
  }
  return null;
}

export function matchAllObsCards( obsCards, files, sortedPoints ) {
  const results = {};
  Object.values( obsCards ).forEach( card => {
    const ts = getCardTimestampMs( card, files );
    if ( ts == null ) return;
    const match = matchTimestampToTrack( ts, sortedPoints );
    if ( match ) {
      results[card.id] = match;
    }
  } );
  return results;
}

import { normalizeTrack } from "../track";
import {
  byName,
  childText,
  parseTimeMs,
  parseXmlDocument
} from "./xml";

// All <trkpt>s from every <trk> and <trkseg> merged into one Track. Recording
// pauses between segments are handled by the matcher's maxGapMs.
export default function fromGpx( xmlString, { parseXml } = {} ) {
  const doc = parseXmlDocument( xmlString, parseXml );
  if ( doc.documentElement.localName !== "gpx" ) {
    throw new Error( "Not a GPX document" );
  }
  const trk = byName( doc, "trk" )[0];
  const points = byName( doc, "trkpt" ).map( pt => ( {
    lat: parseFloat( pt.getAttribute( "lat" ) ),
    lng: parseFloat( pt.getAttribute( "lon" ) ),
    timeMs: parseTimeMs( childText( pt, "time" ) ),
    ele: parseFloat( childText( pt, "ele" ) )
  } ) );
  return normalizeTrack( {
    source: "gpx",
    name: trk ? childText( trk, "name" ) : "",
    points
  } );
}

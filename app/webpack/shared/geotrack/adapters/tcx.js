import { normalizeTrack } from "../track";
import {
  byName,
  childText,
  parseTimeMs,
  parseXmlDocument
} from "./xml";

// Garmin Training Center XML. Trackpoints without a <Position> (e.g. indoor
// or GPS-less samples) are dropped by normalizeTrack.
export default function fromTcx( xmlString, { parseXml } = {} ) {
  const doc = parseXmlDocument( xmlString, parseXml );
  if ( doc.documentElement.localName !== "TrainingCenterDatabase" ) {
    throw new Error( "Not a TCX document" );
  }
  const activity = byName( doc, "Activity" )[0];
  const points = byName( doc, "Trackpoint" ).map( pt => ( {
    lat: parseFloat( childText( pt, "LatitudeDegrees" ) ),
    lng: parseFloat( childText( pt, "LongitudeDegrees" ) ),
    timeMs: parseTimeMs( childText( pt, "Time" ) ),
    ele: parseFloat( childText( pt, "AltitudeMeters" ) )
  } ) );
  return normalizeTrack( {
    source: "tcx",
    name: activity ? ( activity.getAttribute( "Sport" ) || "" ) : "",
    points
  } );
}

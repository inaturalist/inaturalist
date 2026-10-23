// Garmin FIT activity files. Uses fit-file-parser's raw reader rather than
// its full parser, which bundles ~450 KB of FIT profile tables we don't need.
// "fit-file-parser/raw" is a package.json "exports" subpath, which our
// eslint node resolver doesn't understand; webpack and jest resolve it fine
// eslint-disable-next-line import/no-unresolved
import { fitTimestampToUnixMilliseconds, readFitMessages } from "fit-file-parser/raw";
import { normalizeTrack } from "../track";

const RECORD_MESSAGE = 20;
const POSITION_LAT_FIELD = 0;
const POSITION_LONG_FIELD = 1;
const SINT32_INVALID = 0x7FFFFFFF;
const DEGREES_PER_SEMICIRCLE = 180 / 2 ** 31;

function semicirclesToDegrees( fields, fieldNumber, littleEndian ) {
  const field = fields.find( f => f.fieldNumber === fieldNumber );
  if ( !field || field.size !== 4 ) return NaN;
  const view = new DataView( field.bytes.buffer, field.bytes.byteOffset, 4 );
  const semicircles = view.getInt32( 0, littleEndian );
  return semicircles === SINT32_INVALID ? NaN : semicircles * DEGREES_PER_SEMICIRCLE;
}

export default async function fromFit( arrayBuffer ) {
  let result;
  try {
    result = readFitMessages( arrayBuffer, { messageNumbers: [RECORD_MESSAGE] } );
  } catch ( e ) {
    throw new Error( "Invalid FIT file" );
  }
  const points = result.messages.map( message => {
    const timestamp = message.timestamp ?? message.compressedTimestamp;
    return {
      lat: semicirclesToDegrees( message.fields, POSITION_LAT_FIELD, message.littleEndian ),
      lng: semicirclesToDegrees( message.fields, POSITION_LONG_FIELD, message.littleEndian ),
      timeMs: Number.isFinite( timestamp ) ? fitTimestampToUnixMilliseconds( timestamp ) : NaN
    };
  } );
  return normalizeTrack( { source: "fit", name: "", points } );
}

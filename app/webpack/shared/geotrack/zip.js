// Minimal zip reader for single-file archives such as Garmin's activity
// downloads. Supports stored and deflated entries, not zip64 or encryption.

const END_OF_CENTRAL_DIRECTORY = 0x06054b50;
const CENTRAL_DIRECTORY_ENTRY = 0x02014b50;
const LOCAL_FILE_HEADER = 0x04034b50;
const END_OF_CENTRAL_DIRECTORY_SIZE = 22;
const MAX_COMMENT_SIZE = 0xFFFF;
const STORED = 0;
const DEFLATED = 8;
const ZIP64_MARKER = 0xFFFFFFFF;

export const DEFAULT_MAX_UNZIPPED_BYTES = 100 * 1024 * 1024;

// Inflates with DecompressionStream (browsers, Node 18+). Platforms without it,
// such as older React Native, pass their own inflateRaw.
async function defaultInflateRaw( bytes, maxBytes ) {
  if ( typeof DecompressionStream === "undefined" ) {
    throw new Error( "DecompressionStream is unavailable; pass an inflateRaw function" );
  }
  const stream = new DecompressionStream( "deflate-raw" );
  const writer = stream.writable.getWriter( );
  writer.write( bytes ).catch( ( ) => {} );
  writer.close( ).catch( ( ) => {} );
  const reader = stream.readable.getReader( );
  const chunks = [];
  let total = 0;
  for ( ;; ) {
    // eslint-disable-next-line no-await-in-loop
    const { done, value } = await reader.read( );
    if ( done ) break;
    total += value.length;
    if ( total > maxBytes ) {
      reader.cancel( ).catch( ( ) => {} );
      throw new Error( "Zip entry is too large" );
    }
    chunks.push( value );
  }
  const out = new Uint8Array( total );
  let offset = 0;
  chunks.forEach( chunk => {
    out.set( chunk, offset );
    offset += chunk.length;
  } );
  return out;
}

function findEndOfCentralDirectory( view ) {
  const last = view.byteLength - END_OF_CENTRAL_DIRECTORY_SIZE;
  const first = Math.max( 0, last - MAX_COMMENT_SIZE );
  for ( let i = last; i >= first; i -= 1 ) {
    if ( view.getUint32( i, true ) === END_OF_CENTRAL_DIRECTORY ) return i;
  }
  throw new Error( "Not a zip archive" );
}

function decodeName( bytes ) {
  return new TextDecoder( ).decode( bytes );
}

// The first file entry in the central directory (directories are skipped)
function findFirstFileEntry( arrayBuffer, view ) {
  const end = findEndOfCentralDirectory( view );
  const entryCount = view.getUint16( end + 10, true );
  let offset = view.getUint32( end + 16, true );
  for ( let i = 0; i < entryCount; i += 1 ) {
    if ( view.getUint32( offset, true ) !== CENTRAL_DIRECTORY_ENTRY ) {
      throw new Error( "Corrupt zip central directory" );
    }
    const nameLength = view.getUint16( offset + 28, true );
    const name = decodeName( new Uint8Array( arrayBuffer, offset + 46, nameLength ) );
    if ( !name.endsWith( "/" ) ) {
      return {
        name,
        method: view.getUint16( offset + 10, true ),
        compressedSize: view.getUint32( offset + 20, true ),
        size: view.getUint32( offset + 24, true ),
        localOffset: view.getUint32( offset + 42, true )
      };
    }
    offset += 46 + nameLength
      + view.getUint16( offset + 30, true )
      + view.getUint16( offset + 32, true );
  }
  throw new Error( "Zip archive has no files" );
}

// Returns { name, bytes } for the first file in the archive.
// options.inflateRaw( Uint8Array, maxBytes ) => Promise<Uint8Array>
export async function extractFirstFile( arrayBuffer, options = {} ) {
  const maxBytes = options.maxBytes || DEFAULT_MAX_UNZIPPED_BYTES;
  const inflateRaw = options.inflateRaw || defaultInflateRaw;
  const view = new DataView( arrayBuffer );
  const {
    name,
    method,
    compressedSize,
    size,
    localOffset
  } = findFirstFileEntry( arrayBuffer, view );
  if ( compressedSize === ZIP64_MARKER || size === ZIP64_MARKER ) {
    throw new Error( "Zip64 archives are not supported" );
  }
  if ( size > maxBytes ) throw new Error( "Zip entry is too large" );
  if ( view.getUint32( localOffset, true ) !== LOCAL_FILE_HEADER ) {
    throw new Error( "Corrupt zip local header" );
  }
  const dataStart = localOffset + 30
    + view.getUint16( localOffset + 26, true )
    + view.getUint16( localOffset + 28, true );
  const data = new Uint8Array( arrayBuffer, dataStart, compressedSize );
  if ( method === STORED ) return { name, bytes: data.slice( ) };
  if ( method === DEFLATED ) return { name, bytes: await inflateRaw( data, maxBytes ) };
  throw new Error( `Unsupported zip compression method ${method}` );
}

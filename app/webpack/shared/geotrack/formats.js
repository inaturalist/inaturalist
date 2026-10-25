export const TRACK_FORMATS = {
  gpx: { extension: ".gpx", binary: false },
  tcx: { extension: ".tcx", binary: false },
  fit: { extension: ".fit", binary: true }
};

export const TRACK_FILE_EXTENSIONS = Object.values( TRACK_FORMATS ).map( f => f.extension );

export function trackFormatFromFileName( fileName ) {
  const lower = ( fileName || "" ).toLowerCase( );
  return Object.keys( TRACK_FORMATS ).find( format => (
    lower.endsWith( TRACK_FORMATS[format].extension )
  ) ) || null;
}

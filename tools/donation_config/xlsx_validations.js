// exceljs stores data validations per cell and, on write, merges them into
// overlapping ranges whose relative formulas point at the wrong rows. These
// helpers write <dataValidations> into the sheet XML directly instead.

const JSZip = require( "jszip" );

const esc = value => String( value )
  .replace( /&/g, "&amp;" )
  .replace( /</g, "&lt;" )
  .replace( />/g, "&gt;" )
  .replace( /"/g, "&quot;" );

// Maps each tab name to its worksheet XML path inside the zip
async function sheetPaths( zip ) {
  const workbook = await zip.file( "xl/workbook.xml" ).async( "string" );
  const rels = await zip.file( "xl/_rels/workbook.xml.rels" ).async( "string" );
  const targets = {};
  for ( const m of rels.matchAll( /<Relationship\b[^>]*>/g ) ) {
    const id = m[0].match( /Id="([^"]+)"/ )[1];
    const target = m[0].match( /Target="([^"]+)"/ )[1];
    targets[id] = target.startsWith( "/" ) ? target.slice( 1 ) : `xl/${target}`;
  }
  const paths = {};
  for ( const m of workbook.matchAll( /<sheet\b[^>]*>/g ) ) {
    const name = m[0].match( /name="([^"]+)"/ )[1]
      .replace( /&amp;/g, "&" ).replace( /&quot;/g, "\"" );
    const id = m[0].match( /r:id="([^"]+)"/ )[1];
    paths[name] = targets[id];
  }
  return paths;
}

const BLOCK = /<dataValidations\b[\s\S]*?<\/dataValidations>|<dataValidations\b[^>]*\/>/;

function replaceBlock( xml, block ) {
  const stripped = xml.replace( BLOCK, "" );
  if ( !block ) return stripped;
  // dataValidations comes before these elements in the sheet schema
  const anchor = stripped.match( /<(hyperlinks|printOptions|pageMargins|pageSetup|headerFooter|drawing|legacyDrawing|tableParts|extLst)[ >/]/ );
  const at = anchor ? anchor.index : stripped.lastIndexOf( "</worksheet>" );
  return stripped.slice( 0, at ) + block + stripped.slice( at );
}

function validationBlock( validations ) {
  if ( validations.length === 0 ) return "";
  const body = validations.map( v => {
    const attrs = [
      `type="${v.type}"`,
      v.operator ? `operator="${v.operator}"` : null,
      "allowBlank=\"1\"",
      "showErrorMessage=\"1\"",
      `errorTitle="${esc( v.errorTitle )}"`,
      `error="${esc( v.error )}"`,
      `sqref="${v.sqref}"`
    ].filter( Boolean ).join( " " );
    return `<dataValidation ${attrs}><formula1>${esc( v.formula )}</formula1></dataValidation>`;
  } ).join( "" );
  return `<dataValidations count="${validations.length}">${body}</dataValidations>`;
}

// validationsBySheet: { "Countries": [{ sqref, type, formula, ... }] }
async function writeValidations( buffer, validationsBySheet ) {
  const zip = await JSZip.loadAsync( buffer );
  const paths = await sheetPaths( zip );
  for ( const [name, path] of Object.entries( paths ) ) {
    const xml = await zip.file( path ).async( "string" );
    zip.file( path, replaceBlock( xml, validationBlock( validationsBySheet[name] || [] ) ) );
  }
  return zip.generateAsync( { type: "nodebuffer", compression: "DEFLATE" } );
}

// Copies each tab's <dataValidations> from the original file onto a file
// exceljs re-wrote, so a filled copy keeps the original dropdowns and checks
async function restoreValidations( originalBuffer, rewrittenBuffer ) {
  const original = await JSZip.loadAsync( originalBuffer );
  const rewritten = await JSZip.loadAsync( rewrittenBuffer );
  const originalPaths = await sheetPaths( original );
  const rewrittenPaths = await sheetPaths( rewritten );
  for ( const [name, path] of Object.entries( rewrittenPaths ) ) {
    const xml = await rewritten.file( path ).async( "string" );
    let block = "";
    if ( originalPaths[name] ) {
      const source = await original.file( originalPaths[name] ).async( "string" );
      block = ( source.match( BLOCK ) || [""] )[0];
    }
    rewritten.file( path, replaceBlock( xml, block ) );
  }
  return rewritten.generateAsync( { type: "nodebuffer", compression: "DEFLATE" } );
}

module.exports = { writeValidations, restoreValidations, sheetPaths };

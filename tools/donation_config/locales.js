// iNat's supported locales, their English names, and the existing Crowdin
// translation of "Donate" for each, read from config/locales.

const fs = require( "node:fs" );
const path = require( "node:path" );
const yaml = require( "js-yaml" );

const LOCALES_DIR = path.resolve( __dirname, "../../config/locales" );

// Same filter as I18N_SUPPORTED_LOCALES in config/initializers/i18n.rb, minus
// iw (an alias of he) and non-locale files such as doorkeeper.en.yml
function localeCodes( ) {
  return fs.readdirSync( LOCALES_DIR )
    .filter( f => f.endsWith( ".yml" ) )
    .map( f => f.replace( /\.yml$/, "" ) )
    .filter( c => c !== "qqq" && c !== "iw" && !/phonetic|\./.test( c ) )
    .sort( );
}

// Reads one top-level key without parsing the whole (large) locale file
function topLevelValue( code, key ) {
  const text = fs.readFileSync( path.join( LOCALES_DIR, `${code}.yml` ), "utf8" );
  const line = text.match( new RegExp( `^  ${key}: (.+)$`, "m" ) );
  if ( !line ) return null;
  return yaml.load( `v: ${line[1]}` ).v;
}

let cache;
function loadLocales( ) {
  if ( cache ) return cache;
  // json: true lets later duplicate keys win, as Ruby's YAML loader does
  const en = yaml.load( fs.readFileSync( path.join( LOCALES_DIR, "en.yml" ), "utf8" ), { json: true } ).en;
  const languageNames = new Intl.DisplayNames( ["en"], { type: "language" } );
  const donate = {};
  const codes = localeCodes( );
  codes.forEach( code => { donate[code] = topLevelValue( code, "donate_" ); } );
  cache = codes.map( code => {
    const base = code.split( "-" )[0];
    // Regional locales often have no translation of their own and fall back
    // to the base language in the app
    const fromBase = !donate[code] && base !== code && donate[base];
    return {
      code,
      name: en.locales[code] || languageNames.of( code ),
      donate: donate[code] || ( fromBase ? donate[base] : null ),
      donateFrom: donate[code] ? code : ( fromBase ? base : null )
    };
  } );
  return cache;
}

module.exports = { loadLocales };

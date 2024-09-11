/* global I18n */

// Override default behavior so that defaultValue gets returned even if there
// is a fallback value (i.e. how it works in the Rails gem)
( function ( ) {
  var originalImplementation = I18n.t;
  I18n.t = function ( key, params ) {
    var opts = params || {};
    var keyParts = key.split( "." );
    var translation;
    var base;
    // There's probably a smarter way of dealing with nested keys...
    for ( var i = 0; i < keyParts.length; i += 1 ) {
      base = base || I18n.translations[I18n.locale];
      var candidate = base[keyParts[i]];
      if ( !candidate ) {
        // Missing translation
        break;
      }
      if (
        // found a regular string
        typeof candidate === "string"
        // found a plural
        || candidate.one
      ) {
        // translation found
        translation = candidate;
        break;
      }
      // nested key
      base = candidate;
    }
    if (
      // Needs to be a default value to return on
      opts.defaultValue
      // If a locale was explicitly requested, don't bother with this
      && !opts.locale
      && !translation
    ) {
      return opts.defaultValue;
    }
    return originalImplementation( key, opts );
  };
}( ) );

/* global I18n */

// Add defaultValuePreFallback that gets used if there is no translation in
// the current locale *before* looking for translations in fallback locales.
// This might be used in situations when updating strings and the old string
// is a reasonable alternative before the new string is translated, but we
// don't want to show an English fallbackm, e.g.
// ```
// I18n.t( "new_string", { defaultValue: I18n.t( "old_string" ) } )
// ```
// would show the English translation of "new_string" if the current locale is
// Spanish, because English is the fallback locale of all other locales. If
// we really want to show "old_string" in situations where "new_string" is
// not translated into Spanish yet, we can do
// ```
// I18n.t( "new_string", { defaultValuePreFallback: I18n.t( "old_string" ) } )
// ```
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
      opts.defaultValuePreFallback
      // If a locale was explicitly requested, don't bother with this
      && !opts.locale
      && !translation
    ) {
      return opts.defaultValuePreFallback;
    }
    return originalImplementation( key, opts );
  };
}( ) );

/* global I18n */

// Override default behavior so that defaultValue gets returned even if there
// is a fallback value (i.e. how it works in the Rails gem)
( function ( ) {
  var originalImplementation = I18n.t;
  I18n.t = function ( key, params ) {
    var opts = params || {};
    if (
      // Needs to be a default value to return on
      opts.defaultValue
      // If a locale was explicitly requested, don't bother with this
      && !opts.locale
      && !I18n.translations[I18n.locale][key]
    ) {
      return opts.defaultValue;
    }
    return originalImplementation( key, opts );
  };
}( ) );

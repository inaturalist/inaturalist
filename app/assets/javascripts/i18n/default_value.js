// Override default behavior so that defaultValue gets returned even if there
// is a fallback value (i.e. how it works in the Rails gem)
( function ( ) {
  const originalImplementation = I18n.t;
  I18n.t = function ( key, params ) {
    var opts = params || {};
    if (
      opts.defaultValue
      && (
        originalImplementation( key, opts )
        === originalImplementation( key, Object.assign( {}, opts, { locale: "en" } ) )
      )
    ) {
      return opts.defaultValue;
    }
    return originalImplementation( key, opts );
  };
}( ) );

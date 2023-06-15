/* global I18n */

( function ( ) {
  var originalImplementation = I18n.toTime;

  // Port of i18n_custom_backend.rb override in ruby to support %=b and %=B
  // for lowercase month names
  I18n.toTime = function ( scope, input ) {
    var format = I18n.t( scope, { defaultValue: null } );
    const date = I18n.parseDate( input );
    if ( !format ) return originalImplementation.apply( I18n, [scope, input] );

    if ( !format.match( /%=b/i ) ) {
      return originalImplementation.apply( I18n, [scope, input] );
    }

    format = format.replace( "%=b", I18n.strftime( date, "%b" ).toLowerCase() );
    format = format.replace( "%=B", I18n.strftime( date, "%B" ).toLowerCase() );

    return I18n.strftime( date, format );
  };
}( ) );

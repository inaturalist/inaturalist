/* global I18n */
/* global _ */
( function ( ) {
  I18n.t = function ( key, params ) {
    var translation = I18n.translate( key, params );
    if ( typeof ( translation ) !== "string" ) {
      return translation;
    }
    var matches = ( translation || "" ).match( /@(\w+)\{(.+)\}/ );
    if ( !matches ) return translation;
    var mapping = {};
    _.forEach( matches[2].split( "|" ), function ( piece ) {
      var bits = piece.split( ":" );
      if ( bits.length > 1 ) {
        mapping[bits[0]] = bits[1];
      } else {
        mapping.other = bits[0];
      }
    } );
    var newTranslation = translation.replace( matches[0], mapping.other );
    var inflectionKey = matches[1];
    if ( !inflectionKey ) return newTranslation;
    var inflector = params[inflectionKey];
    if ( !inflector ) return newTranslation;
    var inflectorKeys = I18n.translate( "i18n.inflections.@" + inflectionKey, { defaultValue: null } );
    if ( !inflectorKeys ) return newTranslation;
    var inflectorKey = inflectorKeys[inflector];
    if ( !inflectorKey ) return newTranslation;
    inflectorKey = inflectorKey.replace( "@", "" );
    return translation.replace( matches[0], mapping[inflectorKey] || mapping.other );
  };
}( ) );

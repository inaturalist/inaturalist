var iNatModels = iNatModels || { };

iNatModels.Taxon = function( attrs ) {
  var that = this;
  _.each( attrs, function( value, attr ) {
    that[ attr ] = value;
  });
};

iNatModels.Taxon.prototype.preferredNameInLocale = function( locale, defaultToEnglish ) {
  var nameInLocale;
  if( locale ) { locale = locale.split( "-" )[0]; }
  _.each( this.names, function( n ) {
    if( nameInLocale ) { return; }
    if( n.locale === locale ) { nameInLocale = n.name; }
  });
  if( !nameInLocale && locale != "en" && defaultToEnglish === true ) {
    return this.preferredNameInLocale( "en" );
  }
  return nameInLocale;
};

iNatModels.Taxon.prototype.subtitle = function( locale, defaultToEnglish ) {
  var nameInLocale = this.preferredNameInLocale( locale, defaultToEnglish );
  if( nameInLocale != this.name ) {
    return this.name;
  }
};

var iNatModels = iNatModels || { };

iNatModels.Observation = function( attrs ) {
  var that = this;
  _.each( attrs, function( value, attr ) {
    if( attr === "taxon" ) {
      that[ attr ] = new iNatModels.Taxon( value );
    } else if( attr === "user" ) {
      that[ attr ] = new iNatModels.User( value );
    } else {
      that[ attr ] = value
    };
  });
};

iNatModels.Observation.prototype.photo = function( ) {
  if( this.photos && this.photos.length > 0 ) {
    var url = this.photos[0].url;
    url = url.replace( "square.jpg", "large.jpg" );
    url = url.replace( "square.JPG", "large.JPG" );
    return url;
  }
};

iNatModels.Observation.prototype.displayPlace = function( ) {
  if (this.place_guess) {
    return this.place_guess;
  } else if (this.latitude) {
    return [this.latitude, this.longitude].join(',')
  } else {
    return I18n.t('unknown');
  }
}
var iNatModels = iNatModels || { };

iNatModels.Observation = function( attrs ) {
  var that = this;
  _.each( attrs, function( value, attr ) {
    if( attr === "taxon" ) {
      that[ attr ] = new iNatModels.Taxon( attr );
    } else if( attr === "user" ) {
      that[ attr ]  = new iNatModels.User( attr );
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

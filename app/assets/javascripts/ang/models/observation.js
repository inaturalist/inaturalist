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
  if( !_.isUndefined( this.cachedPhoto ) ) { return this.cachedPhoto; }
  if( this.photos && this.photos.length > 0 ) {
    var url = this.photos[0].url;
    if( !url ) { this.cachedPhoto = null; }
    else {
      this.cachedPhoto = url.replace( /square.(jpe?g|png|gif|\?)/i, function( match, $1 ) {
        return "medium." + $1;
      });
    }
  }
  return this.cachedPhoto;
};

iNatModels.Observation.prototype.hasMedia = function( ) {
  return this.photo( ) || this.hasSound( );
};

iNatModels.Observation.prototype.hasSound = function( ) {
  return (this.sounds && this.sounds.length > 0);
};

iNatModels.Observation.prototype.displayPlace = function( ) {
  if (this.place_guess) {
    return this.place_guess;
  } else if (this.latitude) {
    return [this.latitude, this.longitude].join(',')
  } else {
    return I18n.t('unknown');
  }
};

iNatModels.Observation.prototype.qualityGrade = function( ) {
  if ( this.quality_grade == 'research' ) {
    return I18n.t( 'research_grade' );
  }
  return I18n.t( this.quality_grade || 'casual' );
};

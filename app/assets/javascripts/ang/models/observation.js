/* eslint-disable */
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
  this.identifications_count = _.size( _.filter( this.identifications, "current" ) );
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

iNatModels.Observation.prototype.placeIcon = function( ) {
  if ( this.obscured ) {
    if ( this.geoprivacy === "private" ) {
      return "<i class='geoprivacy-icon icon-icn-location-private' title='"
        + I18n.t( "location_is_private" )
        + "' alt='"
        + I18n.t( "location_is_private" )
        + "' />";
    }
    return "<i class='geoprivacy-icon icon-icn-location-obscured' title='"
      + I18n.t( "location_is_obscured" )
      + "' alt='"
      + I18n.t( "location_is_obscured" )
      + "' />";
  }
  if ( this.location ) {
    return "<i class='fa fa-map-marker' title='"
      + I18n.t( "location_is_public" )
      + "' alt='"
      + I18n.t( "location_is_public" )
      + "' />";
  }
  return "";
}

iNatModels.Observation.prototype.displayPlace = function( ) {
  if ( this.geoprivacy === "private" && !this.location ) {
    return I18n.t( "private_" );
  }
  if (this.place_guess) {
    return this.place_guess;
  }
  if (this.location) {
    return this.location;
  }
  return I18n.t( "location_unknown" );
};

iNatModels.Observation.prototype.qualityGrade = function( ) {
  if ( this.quality_grade == "research" ) {
    return I18n.t( "research_grade" );
  }
  if ( this.quality_grade == "needs_id" ) {
    return I18n.t( "needs_id_" );
  }
  return I18n.t( "casual_" );
};

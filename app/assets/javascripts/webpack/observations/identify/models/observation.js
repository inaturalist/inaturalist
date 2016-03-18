import _ from "underscore";
import Taxon from "./taxon";
import User from "./user";

class Observation {
  constructor( attrs ) {
    for ( const attr of Object.keys( attrs ) ) {
      const value = attrs[attr];
      if ( attr === "taxon" && value && value !== null ) {
        this[attr] = new Taxon( value );
      } else if ( attr === "user" && value && value !== null ) {
        this[attr] = new User( value );
      } else {
        this[attr] = value;
      }
    }
  }

  photo( ) {
    if ( !_.isUndefined( this.cachedPhoto ) ) { return this.cachedPhoto; }
    if ( this.photos && this.photos.length > 0 ) {
      const url = this.photos[0].url;
      if ( !url ) {
        this.cachedPhoto = null;
      } else {
        this.cachedPhoto = url.replace( /square.(jpe?g|png|gif|\?)/i, ( match, ext ) => (
          `medium.${ext}`
        ) );
      }
    }
    return this.cachedPhoto;
  }

  hasMedia( ) {
    return this.photo( ) || this.hasSound( );
  }

  hasSound( ) {
    return ( this.sounds && this.sounds.length > 0 );
  }

  displayPlace( ) {
    if ( this.place_guess ) {
      return this.place_guess;
    } else if ( this.latitude ) {
      return [this.latitude, this.longitude].join( "," );
    }
    return I18n.t( "unknown" );
  }

  qualityGrade( ) {
    if ( this.quality_grade === "research" ) {
      return I18n.t( "research_grade" );
    }
    return I18n.t( this.quality_grade || "casual" );
  }

}

export default Observation;


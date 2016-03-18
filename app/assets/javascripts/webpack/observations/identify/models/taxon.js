import _ from "underscore";
import User from "./user";

class Taxon {
  constructor( attrs ) {
    for ( const attr of Object.keys( attrs ) ) {
      const value = attrs[attr];
      if ( attr === "user" && value && value !== null ) {
        this[attr] = new User( value );
      } else {
        this[attr] = value;
      }
    }
  }

  // static ICONIC_TAXA = <%= Taxon::ICONIC_TAXA.sort.to_json(only: [:id, :name, :rank]) %>;

  iconicTaxonName( ) {
    const that = this;
    const iconicTaxon = _.detect( Taxon.ICONIC_TAXA, ( t ) => ( t.id === that.iconic_taxon_id ) );
    if ( iconicTaxon ) {
      return iconicTaxon.name;
    }
    return "unknown";
  }

  photo( ) {
    return this.default_photo ? this.default_photo.medium_url : this.default_photo_url;
  }

  photoLicenseShort( ) {
    if ( !this.default_photo ) return null;
    if ( !this.default_photo.license_code ||
          this.default_photo.license_code === "c" ) {
      return "©";
    }
    if ( this.default_photo.license_code.match( /^cc-/ ) ) return "CC";
    return this.default_photo.license_code.toUpperCase();
  }

  photoAttribution( ) {
    if ( this.default_photo ) {
      return `${I18n.t( "photo" )}: ${this.default_photo.attribution}`;
    }
    return null;
  }

  establishmentMeansCode( ) {
    if ( !_.isUndefined( this.establishment_means_code ) ) {
      return this.establishment_means_code;
    }
    switch ( this.establishment_means && this.establishment_means.establishment_means ) {
      case "native":
        this.establishment_means_code = "N";
        break;
      case "endemic":
        this.establishment_means_code = "E";
        break;
      case "introduced":
        this.establishment_means_code = "IN";
        break;
      default:
        this.establishment_means_code = null;
    }
    return this.establishment_means_code;
  }

  conservationStatus( ) {
    if ( !_.isUndefined( this.conservationStatusName ) ) {
      return this.conservationStatusName;
    }
    switch ( this.conservation_status && this.conservation_status.status ) {
      case "NE":
        this.conservationStatusName = I18n.t( "not_evaluated" );
        break;
      case "DD":
        this.conservationStatusName = I18n.t( "data_deficient" );
        break;
      case "LC":
        this.conservationStatusName = I18n.t( "least_concern" );
        break;
      case "NT":
        this.conservationStatusName = I18n.t( "near_threatened" );
        break;
      case "VU":
        this.conservationStatusName = I18n.t( "vulnerable" );
        break;
      case "EN":
        this.conservationStatusName = I18n.t( "endangered" );
        break;
      case "CR":
        this.conservationStatusName = I18n.t( "critically_endangered" );
        break;
      case "EW":
        this.conservationStatusName = I18n.t( "extinct_in_the_wild" );
        break;
      case "EX":
        this.conservationStatusName = I18n.t( "extinct" );
        break;
      default:
        this.conservationStatusName = null;
    }
    return this.conservationStatusName;
  }

}

Taxon.ICONIC_TAXA = [];

export default Taxon;

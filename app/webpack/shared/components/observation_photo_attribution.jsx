import React, { PropTypes } from "react";

class ObservationPhotoAttribution extends React.Component {

  /* global iNaturalist */
  render( ) {
    const photo = this.props.photo;
    let user = this.props.photo.user;
    if ( !user && this.props.observation ) {
      user = this.props.observation.user;
    }
    if ( !user ) {
      return (
        <span>{ photo.attribution }</span>
      );
    }
    const userName = user.name || user.login;
    const intro = photo.license_code === "cc0" || photo.license_code === "pd" ?
      userName : `\u00A9 ${userName}`;
    if ( !photo.license_code || photo.license_code.toLowerCase( ) === "c" ) {
      return ( <span>{ intro }, { I18n.t( "all_rights_reserved" ) }</span> );
    }
    if ( photo.license_code === "pd" ) {
      return ( <span>
        { intro }, { I18n.t( "copyright.no_known_copyright_restrictions_text" ) } (
        { I18n.t( "public_domain" ) })
        </span> );
    }
    const licenseText = photo.license_code === "cc0" ?
      I18n.t( "copyright.no_rights_reserved" ) :
      I18n.t( "some_rights_reserved" );
    return (
      <span>
        { intro }, <a href={ iNaturalist.Licenses[photo.license_code.toLowerCase( )].url }>
          { licenseText } ({ iNaturalist.Licenses[photo.license_code.toLowerCase( )].code })
        </a>
      </span>
    );
  }
}

ObservationPhotoAttribution.propTypes = {
  photo: PropTypes.object,
  observation: PropTypes.object
};

export default ObservationPhotoAttribution;

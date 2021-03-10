import React from "react";
import PropTypes from "prop-types";

const LicenseImageRow = ( { license, isModal } ) => {
  if ( !license ) { return null; }
  const iNatLicenses = iNaturalist.Licenses;
  const localizedName = license === "cc0" ? "cc_0" : license.replace( /-/g, "_" );

  const gbifTag = ( ) => (
    <div className="license-tag" title={I18n.t( "suitable_for_the_global_biodiversity_information_facility" )}>
      {I18n.t( "gbif" )}
    </div>
  );

  const wikimediaTag = ( ) => (
    <div className="license-tag wikimedia" title={I18n.t( "suitable_for_wikipedia_and_other_wikimedia_foundation_projects" )}>
      {I18n.t( "wikimedia" )}
    </div>
  );

  const addTags = ( ) => {
    const gbif = ["cc0", "cc-by", "cc-by-nc"];
    const wikimedia = ["cc0", "cc-by", "cc-by-sa"];

    if ( !gbif.includes( license ) && !wikimedia.includes( license ) ) {
      return null;
    }

    return (
      <div className="flex-no-wrap">
        {gbif.includes( license ) && gbifTag( )}
        {wikimedia.includes( license ) && wikimediaTag( )}
      </div>
    );
  };

  const showLicenseImage = ( ) => (
    <img
      id="image-license"
      src={iNatLicenses[license].icon_large}
      alt={license}
      className="license-image"
    />
  );

  const showLicenseName = ( ) => (
    <div>
      <div className="license-name">{I18n.t( `${localizedName}_name` )}</div>
      {addTags( license )}
    </div>
  );

  const noLicenseText = ( ) => (
    <div>
      <label htmlFor="image-license">{I18n.t( "no_license_all_rights_reserved" )}</label>
      <p
        className={`text-muted ${!isModal && "small no-license-description"}`}
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{
          __html: I18n.t( "you_retain_full_copyright", {
            site_name: SITE.name
          } )
        }}
      />
    </div>
  );

  const showLicenseImageAndTags = ( ) => {
    if ( license === "c" ) {
      return noLicenseText( );
    }

    return (
      <div className="license-row">
        {showLicenseImage( license )}
        {showLicenseName( localizedName, license )}
      </div>
    );
  };

  return showLicenseImageAndTags( license );
};

LicenseImageRow.propTypes = {
  license: PropTypes.string,
  isModal: PropTypes.bool
};

export default LicenseImageRow;

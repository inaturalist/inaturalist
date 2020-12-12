import React from "react";
import PropTypes from "prop-types";
import { Modal } from "react-bootstrap";

const CreativeCommonsLicensingModal = ( { show, onClose } ) => {
  const createLicenseList = list => {
    const iNatLicenses = iNaturalist.Licenses;

    return list.map( license => {
      const localizedName = license === "cc0" ? "cc_0" : license.replaceAll( "-", "_" );

      const allRightsReserved = (
        <div>
          <label className="row" htmlFor="license_reserved">{I18n.t( "no_license_all_rights_reserved" )}</label>
          <p
            id="license_reserved"
            className="row text-muted"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: I18n.t( "you_retain_full_copyright", {
                site_name: SITE.name
              } )
            }}
          />
        </div>
      );

      return (
        <div key={localizedName} className="about-licenses-row">
          {license === "c" ? allRightsReserved : (
            <div>
              <div className="row flex-no-wrap white-space">
                <img id="image-license" src={iNatLicenses[license].icon_large} alt={license} />
                <label className="license" htmlFor="image-license">{I18n.t( `${localizedName}_name` )}</label>
              </div>
              <div className="row text-muted">
                {I18n.t( `${localizedName}_description` )}
                <a href={iNatLicenses[license].url}>
                  {` ${I18n.t( "view_license" )}`}
                </a>
              </div>
            </div>
          )}
        </div>
      );
    } );
  };

  return (
    <Modal
      show={show}
      className="CreativeCommonsLicensingModal"
      onHide={onClose}
    >
      <Modal.Header closeButton>
        <Modal.Title>{I18n.t( "about_license_options" )}</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <div className="row">
          <div className="col-xs-5">
            {createLicenseList( ["cc0", "cc-by", "cc-by-nc", "cc-by-nc-sa"] )}
          </div>
          <div className="col-xs-1" />
          <div className="col-xs-5">
            {createLicenseList( ["cc-by-nc-nd", "cc-by-nd", "cc-by-sa", "c"] )}
          </div>
        </div>
      </Modal.Body>
    </Modal>
  );
};

CreativeCommonsLicensingModal.propTypes = {
  show: PropTypes.bool,
  onClose: PropTypes.func
};

export default CreativeCommonsLicensingModal;

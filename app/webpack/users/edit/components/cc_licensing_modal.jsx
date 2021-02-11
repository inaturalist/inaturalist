import React from "react";
import PropTypes from "prop-types";
import { Modal } from "react-bootstrap";

import LicenseImageRow from "./license_image_row";

const CreativeCommonsLicensingModal = ( { show, onClose } ) => {
  const iNatLicenses = iNaturalist.Licenses;

  const showLicenseDescription = license => {
    const localizedName = license === "cc0" ? "cc_0" : license.replace( /-/g, "_" );

    return (
      <div className="text-muted license-description">
        {I18n.t( `${localizedName}_description` )}
        <a href={iNatLicenses[license].url}>
          {` ${I18n.t( "view_license" )}`}
        </a>
      </div>
    );
  };

  const createLicenseList = list => list.map( license => (
    <div key={license} className="about-licenses-row">
      <LicenseImageRow license={license} isModal />
      {license !== "c" && showLicenseDescription( license )}
    </div>
  ) );

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

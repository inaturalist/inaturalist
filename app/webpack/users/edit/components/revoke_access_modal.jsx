import React from "react";
import PropTypes from "prop-types";
import { Modal, Button } from "react-bootstrap";

const RevokeAccessModal = ( {
  show,
  onClose,
  deleteApp,
  siteName,
  appType
} ) => {
  const renderTitle = ( ) => {
    if ( appType === "connectedApp" ) {
      return I18n.t( "disconnect_provider", { provider: siteName } );
    }

    if ( appType === "official" ) {
      return I18n.t( "log_out_of_application", { site_name: siteName } );
    }

    return I18n.t( "revoke_external_application", { site_name: siteName } );
  };

  const renderButtonText = ( ) => {
    if ( appType === "connectedApp" ) {
      return I18n.t( "disconnect_caps" );
    }

    if ( appType === "official" ) {
      return I18n.t( "log_out_caps" );
    }

    return I18n.t( "revoke_caps" );
  };

  return (
    <Modal
      show={show}
      className="RevokeAccessModal"
      onHide={onClose}
    >
      <Modal.Header closeButton>
        <Modal.Title>
          {renderTitle( )}
        </Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <p>
          {appType === "connectedApp"
            ? I18n.t( "this_will_remove_inaturalists_ability_to_access_this_account" )
            : I18n.t( "this_will_sign_you_out_current_session" )}
        </p>
      </Modal.Body>
      <Modal.Footer>
        <div className="buttons">
          <Button bsStyle="primary" onClick={( ) => deleteApp( appType )}>
            {renderButtonText( )}
          </Button>
        </div>
      </Modal.Footer>
    </Modal>
  );
};

RevokeAccessModal.propTypes = {
  show: PropTypes.bool,
  onClose: PropTypes.func,
  deleteApp: PropTypes.func,
  siteName: PropTypes.string,
  appType: PropTypes.string
};

export default RevokeAccessModal;

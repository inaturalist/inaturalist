import React from "react";
import PropTypes from "prop-types";
import { Row, Col } from "react-bootstrap";
import ObservationsGridItemForIdentify from "./observations_grid_item_for_identify";

const ObservationsGrid = ( {
  observations,
  onObservationClick,
  toggleReviewed,
  onAgree,
  grid,
  currentUser,
  imageSize,
  confirmResendConfirmation,
  confirmationEmailSent,
  config
} ) => {
  let confirmationNotice;
  let noObservationsNotice;
  const userLacksInteraction = !config?.currentUser?.privilegedWith( "interaction" );
  if ( userLacksInteraction ) {
    confirmationNotice = (
      <div className="confirm-to-interact">
        <div className="confirm-message">
          { I18n.t( "views.email_confirmation.please_confirm_to_use_this_page" ) }
        </div>
        <div className="confirm-button">
          <a
            href="/users/edit"
            onClick={e => {
              confirmResendConfirmation( );
              e.preventDefault( );
              e.stopPropagation( );
            }}
          >
            <button type="button" className="btn btn-primary emailConfirmationModalTrigger">
              { confirmationEmailSent
                ? I18n.t( "views.email_confirmation.confirmation_email_sent" )
                : I18n.t( "send_confirmation_email" )
              }
            </button>
          </a>
        </div>
      </div>
    );
  } else if ( observations.length === 0 ) {
    noObservationsNotice = (
      <div className="text-center text-muted">
        { I18n.t( "no_matching_observations" ) }
      </div>
    );
  }
  return (
    <Row className={`ObservationsGrid ${grid ? "gridded" : "flowed"} ${imageSize === "large" && "image-size-large"}`}>
      <Col xs={12}>
        { confirmationNotice }
        { noObservationsNotice }
        { observations.map( observation => (
          <ObservationsGridItemForIdentify
            key={observation.id}
            observation={observation}
            onObservationClick={onObservationClick}
            toggleReviewed={toggleReviewed}
            onAgree={onAgree}
            showMagnifier
            currentUser={currentUser}
            imageSize={imageSize}
          />
        ) ) }
      </Col>
    </Row>
  );
};

Col.propTypes = {
  key: PropTypes.number
};
ObservationsGrid.propTypes = {
  observations: PropTypes.arrayOf(
    PropTypes.object
  ).isRequired,
  onObservationClick: PropTypes.func,
  onAgree: PropTypes.func,
  toggleReviewed: PropTypes.func,
  grid: PropTypes.bool,
  currentUser: PropTypes.object,
  imageSize: PropTypes.string,
  confirmResendConfirmation: PropTypes.func,
  confirmationEmailSent: PropTypes.bool,
  config: PropTypes.object
};

export default ObservationsGrid;

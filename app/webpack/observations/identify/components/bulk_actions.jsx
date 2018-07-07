import React from "react";
import PropTypes from "prop-types";
import {
  Button,
  ButtonGroup,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";

const BulkActions = ( {
  reviewAll,
  unreviewAll
} ) => (
  <div className="BulkActions">
    <ButtonGroup justified>
      <OverlayTrigger
        placement="bottom"
        overlay={
          <Tooltip id="review-all-btn-tooltip">
            { I18n.t( "views.observations.identify.review_all_tooltip" ) }
          </Tooltip>
        }
        container={ $( "#wrapper.bootstrap" ).get( 0 ) }
      >
        <Button
          onClick={ ( ) => { reviewAll(); } }
        >
          { I18n.t( "review_all" ) }
        </Button>
      </OverlayTrigger>
      <OverlayTrigger
        placement="bottom"
        overlay={
          <Tooltip id="unreview-all-btn-tooltip">
            { I18n.t( "views.observations.identify.unreview_all_tooltip" ) }
          </Tooltip>
        }
        container={ $( "#wrapper.bootstrap" ).get( 0 ) }
      >
        <Button
          onClick={ ( ) => { unreviewAll(); } }
        >
          { I18n.t( "unreview_all" ) }
        </Button>
      </OverlayTrigger>
    </ButtonGroup>
  </div>
);

BulkActions.propTypes = {
  reviewAll: PropTypes.func,
  unreviewAll: PropTypes.func
};

export default BulkActions;

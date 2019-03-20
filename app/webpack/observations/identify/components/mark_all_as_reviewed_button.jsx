import React from "react";
import PropTypes from "prop-types";
import { Button } from "react-bootstrap";

const MarkAllAsReviewedButton = ( {
  allReviewed,
  reviewAll,
  unreviewAll,
  reviewing
} ) => (
  <Button
    bsStyle={allReviewed ? "primary" : "default"}
    onClick={( ) => ( allReviewed ? unreviewAll( ) : reviewAll( ) )}
    disabled={reviewing}
  >
    { reviewing ? (
      <i className="fa fa-refresh fa-spin fa-fw" />
    ) : (
      <i className={`fa fa-eye${allReviewed ? "-slash" : ""}`} />
    ) }
    { " " }
    {
      allReviewed ? I18n.t( "mark_all_as_unreviewed" ) : I18n.t( "mark_all_as_reviewed" )
    }
  </Button>
);

MarkAllAsReviewedButton.propTypes = {
  reviewAll: PropTypes.func,
  unreviewAll: PropTypes.func,
  allReviewed: PropTypes.bool,
  reviewing: PropTypes.bool
};

export default MarkAllAsReviewedButton;

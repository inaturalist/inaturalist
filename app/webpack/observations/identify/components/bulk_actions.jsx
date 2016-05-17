import React, { PropTypes } from "react";
import { Button } from "react-bootstrap";

const BulkActions = ( {
  reviewAll,
  unreviewAll
} ) => (
  <ul className="BulkActions plain">
    <li>
      <Button
        bsStyle="link"
        onClick={ ( ) => { reviewAll(); } }
      >
        Review All
      </Button>
    </li>
    <li>
      <Button
        bsStyle="link"
        onClick={ ( ) => { unreviewAll(); } }
      >
        Unreview All
      </Button>
    </li>
  </ul>
);

BulkActions.propTypes = {
  reviewAll: PropTypes.func,
  unreviewAll: PropTypes.func
};

export default BulkActions;

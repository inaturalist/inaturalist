import React, { PropTypes, Component } from "react";
import { Row, Col, Button, Glyphicon, DropdownButton, MenuItem } from "react-bootstrap";

class TopMenu extends Component {

  render( ) {
    const { createBlankObsCard, confirmRemoveSelected, selectAll, combineSelected,
      trySubmitObservations, fileChooser, countTotal, countSelected } = this.props;
    return (
      <Row className="control-menu">
        <Col cs="12">
          <DropdownButton bsStyle="default" title="Add" id="add_observation">
            <MenuItem onClick={ fileChooser }>Photo(s)</MenuItem>
            <MenuItem onClick={ createBlankObsCard }>Observation without photo</MenuItem>
          </DropdownButton>
          <Button bsStyle="default" onClick={ confirmRemoveSelected }
            disabled={ countSelected === 0 }
          >
            Remove
            <Glyphicon glyph="minus" />
          </Button>
          <Button bsStyle="default" onClick={ combineSelected } disabled={ countSelected < 2 }>
            Combine
            <Glyphicon glyph="collapse-down" />
          </Button>
          <Button bsStyle="default" onClick={ selectAll } disabled={ countTotal === 0 }>
            Select All
            <Glyphicon glyph="asterisk" />
          </Button>
          <Button className="save" bsStyle="success" onClick={ trySubmitObservations }
            disabled={ countTotal === 0 }
          >
            Submit{ countTotal > 0 ? ` ${countTotal} observation${countTotal > 1 ? "s" : ""}` : "" }
          </Button>
        </Col>
      </Row>
    );
  }
}

TopMenu.propTypes = {
  createBlankObsCard: PropTypes.func,
  confirmRemoveSelected: PropTypes.func,
  selectAll: PropTypes.func,
  selectedObsCards: PropTypes.object,
  trySubmitObservations: PropTypes.func,
  combineSelected: PropTypes.func,
  fileChooser: PropTypes.func,
  countTotal: PropTypes.number,
  countSelected: PropTypes.number
};

export default TopMenu;

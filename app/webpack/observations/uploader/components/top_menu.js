import React, { PropTypes, Component } from "react";
import { Row, Col, Button, Glyphicon } from "react-bootstrap";

class TopMenu extends Component {

  render( ) {
    const { createBlankObsCard, confirmRemoveSelected, selectAll,
      submitObservations, fileChooser, count } = this.props;
    return (
      <Row>
        <Col cs="12" className="conrol-menu">
          <Button bsStyle="primary" bsSize="large" onClick={ createBlankObsCard }>
            New/Blank
            <Glyphicon glyph="file" />
          </Button>
          <Button bsStyle="primary" bsSize="large" onClick={ fileChooser }>
            Add
            <Glyphicon glyph="plus" />
          </Button>
          <Button bsStyle="primary" bsSize="large" onClick={ confirmRemoveSelected }>
            Remove
            <Glyphicon glyph="minus" />
          </Button>
          <Button bsStyle="primary" bsSize="large" onClick={ selectAll }>
            Select All
            <Glyphicon glyph="asterisk" />
          </Button>
          <Button className="save" bsStyle="primary" bsSize="large" onClick={ submitObservations }
            disabled={ count === 0 }
          >
            Submit{ count > 0 ? ` ${count} observations` : "" }
            <Glyphicon glyph="floppy-saved" />
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
  submitObservations: PropTypes.func,
  fileChooser: PropTypes.func,
  count: PropTypes.number
};

export default TopMenu;

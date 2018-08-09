import React from "react";
import PropTypes from "prop-types";
import {
  Modal,
  Button
} from "react-bootstrap";

class FinishedModal extends React.Component {
  render( ) {
    const {
      reviewed,
      total,
      pageTotal,
      visible,
      onClose,
      viewMore,
      loadPage,
      currentPage,
      done
    } = this.props;
    let viewMoreButton;
    if ( reviewed > 0 ) {
      viewMoreButton = (
        <Button
          bsStyle="primary"
          onClick={ ( ) => viewMore( ) }
        >
          { I18n.t( "view_more_unreviewed" ) }
        </Button>
      );
    }
    let nextPageButton = (
      <Button
        bsStyle={ reviewed > 0 ? "default" : "primary" }
        onClick={ ( ) => loadPage( currentPage + 1 ) }
      >
        { I18n.t( "skip_to_next_page" ) }
      </Button>
    );
    let modalBody = (
      <Modal.Body>
        { I18n.t( "views.observations.identify.you_reviewed_message", {
          reviewed, pageTotal, total } ) }
      </Modal.Body>
    );
    let modalFooter = (
      <Modal.Footer>
        { nextPageButton }
        { viewMoreButton }
      </Modal.Footer>
    );
    if ( done ) {
      modalBody = (
        <Modal.Body>
          { I18n.t( "that_was_the_last_observation_matching_the_current_filters" ) }
        </Modal.Body>
      );
      modalFooter = (
        <Modal.Footer>
          <Button
            bsStyle="primary"
            onClick={ ( ) => onClose( ) }
          >
            { I18n.t( "ok" ) }
          </Button>
        </Modal.Footer>
      );
    }
    return (
      <Modal
        show={visible}
        onHide={onClose}
        className="FinishedModal"
        onEntered={ ( ) => {
          $( "button:last", this.refs.target ).focus();
        } }
      >
        <Modal.Header closeButton>
          <Modal.Title>
            { done ? I18n.t( "finished" ) : I18n.t( "finished_with_page" ) }
          </Modal.Title>
        </Modal.Header>
        { modalBody }
        { modalFooter }
      </Modal>
    );
  }
}

FinishedModal.propTypes = {
  reviewed: PropTypes.number,
  total: PropTypes.number,
  pageTotal: PropTypes.number,
  visible: PropTypes.bool,
  onClose: PropTypes.func,
  viewMore: PropTypes.func,
  loadPage: PropTypes.func,
  currentPage: PropTypes.number,
  done: PropTypes.bool
};

export default FinishedModal;

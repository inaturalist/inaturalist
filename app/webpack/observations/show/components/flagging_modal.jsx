import React, { Component, PropTypes } from "react";
import { Button, Glyphicon, Modal } from "react-bootstrap";
import UserImage from "../../identify/components/user_image";

class FlaggingModal extends Component {

  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
    this.setRadioOption = this.setRadioOption.bind( this );
    this.submit = this.submit.bind( this );
  }

  setRadioOption( name ) {
    this.props.setFlaggingModalState( "radioOption", name );
  }

  close( ) {
    this.props.setFlaggingModalState( "show", false );
  }

  submit( ) {
    const item = this.props.state.item;
    const body = this.refs.reason && $( this.refs.reason ).val( );
    let className = "Comment";
    if ( item.observation_id ) {
      className = "Identification";
    } else if ( item.quality_grade ) {
      className = "Observation";
    }
    this.props.createFlag( className, item.id,
      this.props.state.radioOption, body );
    this.close( );
  }

  render( ) {
    const item = this.props.state.item;
    const loggedInUser = this.props.config.currentUser;
    const otherTextarea = this.props.state.radioOption === "other" && (
      <textarea placeholder="Specify the reason you're flagging this item"
        className="form-control" ref="reason"
      /> );
    const existingFlags = item && item.flags && item.flags.length > 0 && (
      <div className="alert alert-warning">
        { item.flags.map( flag => (
          <div>
            <UserImage user={ flag.user } />
            <div className="username">
              <a href={ `/people/${flag.user.login}` }>{ flag.user.login }</a>
            </div>
            { flag.flag }
            { flag.user && loggedInUser && flag.user.id === loggedInUser.id && (
              <Glyphicon glyph="remove-circle"
                onClick={ ( ) => { this.props.deleteFlag( flag.id ); } }
              />
            ) }
          </div>
        ) ) }
      </div>
    );
    return (
      <Modal
        show={ this.props.state.show }
        className="FlaggingModal"
        backdrop="static"
        onHide={ this.close }
      >
        <Modal.Header closeButton>
          <Modal.Title>
            Flag an item
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <div className="text">
            { existingFlags }
            <div className="flagInput">
              <label className="heading">
                <input
                  type="radio"
                  name="spam"
                  checked={ this.props.state.radioOption === "spam" }
                  onClick={ () => { this.setRadioOption( "spam" ); } }
                /> spam
              </label>
              <div className="help-block">
                Commercial solicitation, links to nowhere, etc.
              </div>
            </div>
            <div className="flagInput">
              <label className="heading">
                <input
                  type="radio"
                  name="inappropriate"
                  checked={ this.props.state.radioOption === "inappropriate" }
                  onClick={ () => { this.setRadioOption( "inappropriate" ); } }
                /> offensive / inappropriate
              </label>
              <div className="help-block">
                Misleading or illegal content, racial or ethnic slurs, etc.
                For more on our definition of "appropriate," see the&nbsp;
                <a href="/pages/help#inappropriate">FAQ</a>.
              </div>
            </div>
            <div className="flagInput">
              <label className="heading">
                <input
                  type="radio"
                  name="other"
                  checked={ this.props.state.radioOption === "other" }
                  onClick={ () => { this.setRadioOption( "other" ); } }
                /> other
              </label>
              <div className="help-block">
                Some other reason you can explain below.
              </div>
              { otherTextarea }
            </div>
          </div>
        </Modal.Body>
        <Modal.Footer>
          <div className="buttons">
            <Button onClick={ this.close }>
              { I18n.t( "cancel" ) }
            </Button>
            <Button bsStyle="primary" onClick={ this.submit }>
              { I18n.t( "save" ) }
            </Button>
          </div>
        </Modal.Footer>
      </Modal>
    );
  }
}

FlaggingModal.propTypes = {
  config: PropTypes.object,
  state: PropTypes.object,
  setFlaggingModalState: PropTypes.func,
  createFlag: PropTypes.func,
  deleteFlag: PropTypes.func
};

export default FlaggingModal;

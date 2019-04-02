import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Button, Glyphicon, Modal } from "react-bootstrap";

class FlaggingModal extends Component {
  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
    this.setRadioOption = this.setRadioOption.bind( this );
    this.submit = this.submit.bind( this );
    this.textarea = React.createRef();
    this.state = {
      textareaChars: 0
    };
  }

  setRadioOption( name ) {
    this.props.setFlaggingModalState( { radioOption: name } );
  }

  close( ) {
    this.props.setFlaggingModalState( { show: false } );
  }

  submit( ) {
    const { state: propsState, createFlag } = this.props;
    const { item, radioOption } = propsState;
    const body = this.textarea && this.textarea.current && $( this.textarea.current ).val( );
    let className = "Comment";
    if ( item.constructor.name === "Project" ) {
      className = "Project";
    } else if ( item.quality_grade ) {
      className = "Observation";
    } else if ( item.taxon ) {
      className = "Identification";
    }
    createFlag( className, item.id, radioOption, body );
    this.close( );
  }

  render( ) {
    const {
      state,
      config,
      deleteFlag
    } = this.props;
    const { item, show } = state;
    if ( !item ) {
      return ( <div /> );
    }
    const loggedInUser = config.currentUser;
    const { textareaChars } = this.state;
    const otherTextarea = state.radioOption === "other" && (
      <div>
        <textarea
          placeholder={I18n.t( "specify_the_reason_youre_flagging" )}
          className="form-control"
          ref={this.textarea}
          maxLength={255}
          onChange={e => this.setState( { textareaChars: e.target.value.length } )}
        />
        <div className="text-muted text-small">
          { `${textareaChars} / 255` }
        </div>
      </div>
    );
    const unresolvedFlags = _.filter( item.flags || [], f => !f.resolved );
    const existingFlags = unresolvedFlags.length > 0 && (
      <div className="alert alert-warning">
        { I18n.t( "current_flags" ) }
        <ul>
          { unresolvedFlags.map( flag => (
            <li key={`flag-${flag.id || flag.user.id}`}>
              { flag.flag }
              { " " }
              <a href={`/people/${flag.user.login}`}>{ flag.user.login }</a>
              { flag.user && loggedInUser && flag.user.id === loggedInUser.id && (
                <Glyphicon
                  glyph="remove-circle"
                  onClick={( ) => { deleteFlag( flag.id ); }}
                />
              ) }
            </li>
          ) ) }
        </ul>
      </div>
    );
    return (
      <Modal
        show={show}
        className="FlaggingModal"
        backdrop="static"
        onHide={this.close}
      >
        <Modal.Header closeButton>
          <Modal.Title>
            { I18n.t( "flag_an_item" ) }
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <div className="text">
            <p>{ I18n.t( "flagging_desc" ) }</p>
            { existingFlags }
            <div className="flagInput">
              <label className="heading">
                <input
                  type="radio"
                  name="spam"
                  checked={state.radioOption === "spam"}
                  onChange={() => { this.setRadioOption( "spam" ); }}
                />
                { " " }
                { I18n.t( "spam" ) }
              </label>
              <div className="help-block">
                { I18n.t( "commercial_solicitation" ) }
              </div>
            </div>
            <div className="flagInput">
              <label className="heading">
                <input
                  type="radio"
                  name="inappropriate"
                  checked={state.radioOption === "inappropriate"}
                  onChange={( ) => { this.setRadioOption( "inappropriate" ); }}
                />
                { " " }
                { I18n.t( "offensive_inappropriate" ) }
              </label>
              <div
                className="help-block"
                dangerouslySetInnerHTML={{
                  __html: I18n.t( "misleading_or_illegal_content_html" )
                }}
              />
            </div>
            <div className="flagInput">
              <label className="heading">
                <input
                  type="radio"
                  name="other"
                  checked={state.radioOption === "other"}
                  onChange={( ) => { this.setRadioOption( "other" ); }}
                />
                { " " }
                { I18n.t( "other" ) }
              </label>
              <div className="help-block">
                <p>{ I18n.t( "some_other_reason" ) }</p>
                { item.quality_grade && <p>{ I18n.t( "duplicate_observation_flag_warning" ) }</p>}
              </div>
              { otherTextarea }
            </div>
          </div>
        </Modal.Body>
        <Modal.Footer>
          <div className="buttons">
            <Button onClick={this.close}>
              { I18n.t( "cancel" ) }
            </Button>
            <Button bsStyle="primary" onClick={this.submit}>
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

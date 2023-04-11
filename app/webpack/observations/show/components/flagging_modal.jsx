import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Button, Glyphicon, Modal } from "react-bootstrap";
import {
  Identification,
  Observation,
  Photo,
  Project,
  Sound
} from "inaturalistjs";

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

  getItemClassName( ) {
    const { state: propsState } = this.props;
    const { item } = propsState;
    let className;
    if ( item instanceof Project ) {
      className = "Project";
    } else if ( item instanceof Observation || item.quality_grade ) {
      className = "Observation";
    } else if ( item instanceof Identification || item.taxon ) {
      className = "Identification";
    } else if ( item instanceof Photo || item.square_url ) {
      className = "Photo";
    } else if ( item instanceof Sound || item.file_url ) {
      className = "Sound";
    } else if ( item instanceof Comment ) {
      className = "Comment";
    }
    if ( !className ) {
      throw new Error( "Can't flag an unknown type of item" );
    }
    return className;
  }

  close( ) {
    this.props.setFlaggingModalState( { show: false } );
  }

  submit( ) {
    const { state: propsState, createFlag } = this.props;
    const { item, radioOption } = propsState;
    const body = this.textarea && this.textarea.current && $( this.textarea.current ).val( );
    createFlag(
      this.getItemClassName( ),
      item.id,
      radioOption,
      body
    );
    this.close( );
  }

  render( ) {
    const {
      state,
      config,
      deleteFlag,
      radioOptions
    } = this.props;
    const { item, show } = state;
    if ( !item ) {
      return ( <div /> );
    }
    let title = I18n.t( "flag_an_item" );
    const itemClassName = this.getItemClassName( );
    if ( itemClassName === "Observation" ) {
      title = I18n.t( "flag_this_observation" );
    } else if ( itemClassName === "Photo" ) {
      title = I18n.t( "flag_this_photo" );
    } else if ( itemClassName === "Sound" ) {
      title = I18n.t( "flag_this_sound" );
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
              { flag.user && (
                <a href={`/people/${flag.user.login}`}>{ flag.user.login }</a>
              ) }
              { flag.user && loggedInUser && flag.user.id === loggedInUser.id && (
                <Glyphicon
                  glyph="remove-circle"
                  onClick={( ) => { deleteFlag( flag.id ); }}
                />
              ) }
              { " " }
              <a href={`/flags/${flag.id}`}>
                { I18n.t( "view_flag" ) }
              </a>
            </li>
          ) ) }
        </ul>
      </div>
    );
    const inputs = [];
    if ( radioOptions.indexOf( "spam" ) >= 0 ) {
      inputs.push(
        <div className="flagInput" key="FlaggingModal-input-spam">
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
      );
    }
    if ( radioOptions.indexOf( "inappropriate" ) >= 0 ) {
      inputs.push(
        <div className="flagInput" key="FlaggingModal-input-inappropriate">
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
      );
    }
    if ( radioOptions.indexOf( "copyright infringement" ) >= 0 ) {
      inputs.push(
        <div className="flagInput" key="FlaggingModal-input-copyright">
          <label className="heading">
            <input
              type="radio"
              name="copyright_infringement"
              checked={state.radioOption === "copyright infringement"}
              onChange={( ) => { this.setRadioOption( "copyright infringement" ); }}
            />
            { " " }
            { I18n.t( "copyright_infringement" ) }
          </label>
          <div
            className="help-block"
            dangerouslySetInnerHTML={{
              __html: I18n.t( "copyright_infringement_desc" )
            }}
          />
        </div>
      );
    }
    return (
      <Modal
        show={show}
        className="FlaggingModal"
        backdrop
        onHide={this.close}
      >
        <Modal.Header closeButton>
          <Modal.Title>
            { title }
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <div className="text">
            <p>{ I18n.t( "flagging_desc" ) }</p>
            { existingFlags }
            { inputs }
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
                { item.quality_grade && (
                  <div className="alert alert-warning">
                    <p>{ I18n.t( "duplicate_observation_flag_warning" ) }</p>
                  </div>
                ) }
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
  deleteFlag: PropTypes.func,
  radioOptions: PropTypes.array
};

FlaggingModal.defaultProps = {
  radioOptions: ["spam", "inappropriate"]
};

export default FlaggingModal;

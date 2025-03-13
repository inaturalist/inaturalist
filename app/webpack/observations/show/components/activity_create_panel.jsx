import _ from "lodash";
import React from "react";
import ReactDOM from "react-dom";
import PropTypes from "prop-types";
import {
  Tab,
  Tabs
} from "react-bootstrap";
import TaxonAutocomplete from "../../uploader/components/taxon_autocomplete";
import TextEditor from "../../../shared/components/text_editor";

class ActivityCreatePanel extends React.Component {
  constructor( ) {
    super( );
    this.setUpMentionsAutocomplete = this.setUpMentionsAutocomplete.bind( this );
  }

  componentDidMount( ) {
    this.setUpMentionsAutocomplete( );
  }

  shouldComponentUpdate( nextProps ) {
    const { observation, activeTab, content } = this.props;
    if ( observation.id === nextProps.observation.id
      && activeTab === nextProps.activeTab
      && content === nextProps.content ) {
      return false;
    }
    return true;
  }

  componentDidUpdate( ) {
    this.setUpMentionsAutocomplete( );
  }

  setUpMentionsAutocomplete( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "textarea", domNode ).textcompleteUsers( );
  }

  postIdentification( ) {
    const { addID, content, updateEditorContent } = this.props;
    const input = $( ".id_tab input[name='taxon_name']" );
    const selectedTaxon = input.data( "uiAutocomplete" ).selectedItem;
    if ( selectedTaxon ) {
      addID( selectedTaxon, { body: content } );
      input.trigger( "resetSelection" );
      input.val( "" );
      input.data( "uiAutocomplete" ).selectedItem = null;

      updateEditorContent( "activity", "" );
    }
  }

  commentContent( ) {
    const {
      config,
      observation,
      content,
      updateEditorContent,
      confirmResendConfirmation
    } = this.props;
    if ( !config?.currentUser ) {
      return (
        <span
          className="log-in"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "log_in_or_sign_up_to_add_comments_html" )
          }}
        />
      );
    }
    if ( config?.currentUserCanInteractWithResource( observation ) ) {
      return (
        <div className="form-group">
          <TextEditor
            key={`comment-editor-${observation.id}-${_.size( observation.comments )}`}
            placeholder={I18n.t( "leave_a_comment" )}
            textareaClassName="form-control"
            maxLength={5000}
            content={content}
            showCharsRemainingAt={4000}
            onBlur={e => updateEditorContent( "activity", e.target.value )}
          />
        </div>
      );
    }
    return (
      <div className="confirm-to-interact">
        <div className="confirm-message">
          { I18n.t( "views.email_confirmation.please_confirm_to_interact" ) }
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
              { I18n.t( "send_confirmation_email" ) }
            </button>
          </a>
        </div>
      </div>
    );
  }

  idContent( ) {
    const {
      config,
      observation,
      content,
      updateEditorContent,
      confirmResendConfirmation
    } = this.props;
    if ( !( config && config.currentUser ) ) {
      return (
        <span
          className="log-in"
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{
            __html: I18n.t( "log_in_or_sign_up_to_add_identifications_html" )
          }}
        />
      );
    }
    if ( config?.currentUserCanInteractWithResource( observation ) ) {
      // attempting to match the logic in the computervision/score_observation endpoint
      // so we don't attempt to fetch vision results for obs which will have no results
      const visionEligiblePhotos = _.compact( _.map( observation.photos, p => {
        if ( !p.url || p.preview ) { return null; }
        const mediumUrl = p.photoUrl( "medium" );
        if ( mediumUrl && mediumUrl.match( /\/medium[./]/i ) ) {
          return p;
        }
        return null;
      } ) );
      return (
        <div>
          <TaxonAutocomplete
            bootstrap
            searchExternal
            perPage={6}
            resetOnChange={false}
            visionParams={
              visionEligiblePhotos.length > 0
                ? { observationID: observation.id, observationUUID: observation.uuid }
                : null
            }
            config={config}
            onKeyDown={e => {
              const key = e.keyCode || e.which;
              if ( key === 13 ) {
                this.postIdentification( );
              }
            }}
          />
          <div className="form-group">
            <TextEditor
              key={`comment-editor-${observation.id}-${_.size( observation.identifications )}`}
              placeholder={I18n.t( "tell_us_why" )}
              className="upstacked"
              textareaClassName="form-control"
              onBlur={e => updateEditorContent( "activity", e.target.value )}
              content={content}
              maxLength={5000}
              showCharsRemainingAt={4000}
            />
          </div>
        </div>
      );
    }
    return (
      // eslint-disable-next-line jsx-a11y/control-has-associated-label
      <div className="confirm-to-interact">
        <div className="confirm-message">
          { I18n.t( "views.email_confirmation.please_confirm_to_interact" ) }
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
              { I18n.t( "send_confirmation_email" ) }
            </button>
          </a>
        </div>
      </div>
    );
  }

  render( ) {
    const {
      observation,
      activeTab,
      setActiveTab
    } = this.props;
    if ( !observation ) { return ( <div /> ); }
    const tabs = (
      <Tabs
        id="comment-id-tabs"
        activeKey={activeTab}
        onSelect={key => {
          setActiveTab( key );
        }}
      >
        <Tab eventKey="comment" title={I18n.t( "comment_" )} className="comment_tab">
          { this.commentContent( ) }
        </Tab>
        <Tab eventKey="add_id" title={I18n.t( "suggest_an_identification" )} className="id_tab">
          { this.idContent( ) }
        </Tab>
      </Tabs>
    );
    return (
      <div className="comment_id_panel" key={`activity-panel-${observation.id}`}>
        { tabs }
      </div>
    );
  }
}

ActivityCreatePanel.propTypes = {
  observation: PropTypes.object,
  config: PropTypes.object,
  activeTab: PropTypes.string,
  addID: PropTypes.func,
  content: PropTypes.string,
  setActiveTab: PropTypes.func,
  updateEditorContent: PropTypes.func,
  confirmResendConfirmation: PropTypes.func
};

export default ActivityCreatePanel;

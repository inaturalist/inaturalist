import _ from "lodash";
import React, { useEffect, useRef } from "react";
import { Tab, Tabs } from "react-bootstrap";
import TaxonCombobox from "../../../shared/components/taxon_combobox";
import TextEditor from "../../../shared/components/text_editor";
import type { Config, Observation, Photo } from "../../../shared/types";

type PanelPhoto = Photo & { url?: string; preview?: boolean };

type PanelObservation = Omit<Observation, "photos"> & {
  uuid?: string;
  photos?: PanelPhoto[];
  identifications?: unknown[];
  comments?: unknown[];
};

type PanelConfig = Config & {
  currentUserCanInteractWithResource?: ( observation: unknown ) => boolean;
};

interface Props {
  observation?: PanelObservation;
  config?: PanelConfig;
  activeTab?: string;
  nominate?: boolean;
  content?: string;
  suggestedTaxon?: INatTaxonRecord | null;
  addID?: ( taxon: INatTaxonRecord, options: { body?: string } ) => void;
  setActiveTab?: ( tab: string ) => void;
  setNominateOnSubmit?: ( nominate: boolean ) => void;
  setSuggestedTaxon?: ( taxon: INatTaxonRecord | null ) => void;
  updateEditorContent?: ( editor: string, content: string ) => void;
  confirmResendConfirmation?: ( method?: string ) => void;
}

const confirmToInteract = ( confirmResendConfirmation?: Props["confirmResendConfirmation"] ) => (
  // eslint-disable-next-line jsx-a11y/control-has-associated-label
  <div className="confirm-to-interact">
    <div className="confirm-message">
      { I18n.t( "views.email_confirmation.please_confirm_to_interact" ) }
    </div>
    <div className="confirm-button">
      <a
        href="/users/edit"
        onClick={e => {
          confirmResendConfirmation?.( );
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

const ActivityCreatePanel = ( {
  observation,
  config,
  activeTab,
  nominate,
  content,
  suggestedTaxon,
  addID,
  setActiveTab,
  setNominateOnSubmit,
  setSuggestedTaxon,
  updateEditorContent,
  confirmResendConfirmation
}: Props ) => {
  const rootRef = useRef<HTMLDivElement>( null );

  useEffect( ( ) => {
    $( "textarea", rootRef.current ).textcompleteUsers( );
  } );

  const postIdentification = ( ) => {
    if ( !suggestedTaxon ) { return; }
    addID?.( suggestedTaxon, { body: content } );
    setSuggestedTaxon?.( null );
    updateEditorContent?.( "activity", "" );
    setNominateOnSubmit?.( false );
  };

  const commentContent = ( ) => {
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
    if ( config?.currentUserCanInteractWithResource?.( observation ) ) {
      return (
        <div className="form-group">
          <TextEditor
            key={`comment-editor-${observation?.id}-${_.size( observation?.comments )}`}
            placeholder={I18n.t( "leave_a_comment" )}
            textareaClassName="form-control"
            maxLength={5000}
            content={content}
            showCharsRemainingAt={4000}
            onBlur={( e: React.FocusEvent<HTMLTextAreaElement> ) => {
              updateEditorContent?.( "activity", e.target.value );
            }}
          />
        </div>
      );
    }
    return confirmToInteract( confirmResendConfirmation );
  };

  const idContent = ( ) => {
    if ( !config?.currentUser ) {
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
    const { currentUser } = config;
    if ( !config?.currentUserCanInteractWithResource?.( observation ) ) {
      return confirmToInteract( confirmResendConfirmation );
    }
    // Match the computervision/score_observation endpoint's logic so we don't fetch vision
    // results for observations that would have none.
    const visionEligiblePhotos = _.compact( _.map( observation?.photos, p => {
      if ( !p.url || p.preview ) { return null; }
      const mediumUrl = p.photoUrl( "medium" );
      return mediumUrl && mediumUrl.match( /\/medium[./]/i ) ? p : null;
    } ) );
    const visionParams = visionEligiblePhotos.length > 0 && observation
      ? { observationID: observation.id, observationUUID: observation.uuid }
      : null;
    return (
      <div>
        <TaxonCombobox
          key={`taxon-combobox-${observation?.id}-${_.size( observation?.identifications )}`}
          config={config}
          perPage={6}
          searchExternal
          visionParams={visionParams}
          onSelect={taxon => { setSuggestedTaxon?.( taxon ); }}
          onKeyDown={e => {
            if ( ( e.keyCode || e.which ) === 13 ) { postIdentification( ); }
          }}
        />
        <div className="form-group">
          <TextEditor
            key={`comment-editor-${observation?.id}-${_.size( observation?.identifications )}`}
            placeholder={I18n.t( "tell_us_why" )}
            className="upstacked"
            textareaClassName="form-control"
            onBlur={( e: React.FocusEvent<HTMLTextAreaElement> ) => {
              updateEditorContent?.( "activity", e.target.value );
            }}
            onChange={( e: React.ChangeEvent<HTMLTextAreaElement> ) => {
              const textLength = _.size( e.target.value );
              if ( textLength === 0 ) {
                // TODO: figure out a better way to avoid the React controlled input error
                $( ".nomination input[type='checkbox']" ).prop( "checked", false );
                setNominateOnSubmit?.( false );
              }
              $( ".nomination input[type='checkbox']" ).prop( "disabled", textLength === 0 );
            }}
            content={content}
            maxLength={5000}
            showCharsRemainingAt={4000}
          />
          { currentUser?.canNominateHelpfulIDTips?.( ) && (
            <div className="nomination">
              <input
                type="checkbox"
                id="nominate-id"
                defaultChecked={nominate}
                disabled={_.size( content ) === 0}
                onChange={e => { setNominateOnSubmit?.( e.target.checked ); }}
                tabIndex={-1}
              />
              <label className="identificationNomination" htmlFor="nominate-id">
                { I18n.t( "identification_tips.nominate_as_an_id_tip_with_explanation" ) }
              </label>
            </div>
          ) }
        </div>
      </div>
    );
  };

  if ( !observation ) { return ( <div /> ); }
  return (
    <div className="comment_id_panel" ref={rootRef}>
      <Tabs
        id="comment-id-tabs"
        activeKey={activeTab}
        onSelect={( key: string ) => { setActiveTab?.( key ); }}
      >
        <Tab eventKey="comment" title={I18n.t( "comment_" )} className="comment_tab">
          { commentContent( ) }
        </Tab>
        <Tab eventKey="add_id" title={I18n.t( "suggest_an_identification" )} className="id_tab">
          { idContent( ) }
        </Tab>
      </Tabs>
    </div>
  );
};

// Mirror the legacy shouldComponentUpdate, plus suggestedTaxon so the Enter-submit closure
// (which reads it) stays current.
const areEqual = ( prev: Props, next: Props ) => prev.observation?.id === next.observation?.id
  && prev.activeTab === next.activeTab
  && prev.content === next.content
  && prev.suggestedTaxon === next.suggestedTaxon;

export default React.memo( ActivityCreatePanel, areEqual );

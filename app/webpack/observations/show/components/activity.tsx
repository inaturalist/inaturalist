import _ from "lodash";
import React, { useEffect } from "react";
import { Button, OverlayTrigger, Tooltip } from "react-bootstrap";
import moment from "moment-timezone";
import { addImplicitDisagreementsToActivity } from "../../../shared/util";
import UserImage from "../../../shared/components/user_image";
import ActivityItem, { ActivityItemProps } from "./activity_item";
import ActivityCreatePanelContainer from "../containers/activity_create_panel_container";

type ActivityProps = Omit<ActivityItemProps, "item" | "currentUserID" | "inlineEditing"> & {
  addComment?: ( body: string ) => void;
  content?: string;
  review?: ( ) => void;
  unreview?: ( ) => void;
  updateEditorContent?: ( editor: string, content: string ) => void;
  setNominateOnSubmit?: ( nominate: boolean ) => void;
  nominate?: boolean;
};

const Activity = ( props: ActivityProps ) => {
  const {
    observation,
    config,
    addComment,
    addID,
    confirmDeleteID,
    content,
    deleteComment,
    editComment,
    editID,
    hideAgree,
    hideCategory,
    hideCompare,
    hideContent,
    hideDisagreement,
    hideMenu,
    hideUserIcon,
    linkTarget,
    nominate,
    noTaxonLink,
    onClickCompare,
    performOrOpenConfirmationModal,
    restoreID,
    review,
    setFlaggingModalState,
    setNominateOnSubmit,
    showHidden,
    trustUser,
    unhideContent,
    unreview,
    untrustUser,
    unvoteIdentification,
    updateEditorContent,
    voteIdentification,
    withdrawID,
    nominateIdentification,
    unnominateIdentification
  } = props;

  useEffect( ( ) => {
    if ( window.location.hash ) {
      // Without the timeout Chrome scrolls back to the top; $.scrollTo doesn't work in Safari
      let targetHash = window.location.hash;
      const actionMatches = targetHash.match( /(.*):(.*)/ );
      if ( actionMatches !== null ) {
        targetHash = actionMatches[1];
      }
      if ( ( $( targetHash ) as any ).length === 0 ) {
        targetHash = _.replace( `activity_${targetHash.replace( "#", "" )}`, "-", "_" );
        targetHash = `#${targetHash}`;
      }
      const isFirefox = navigator.userAgent.toLowerCase( ).indexOf( "firefox" ) > -1;
      if ( isFirefox ) {
        ( $ as any ).scrollTo( targetHash );
      } else {
        setTimeout( ( ) => {
          const $hashElt = $( targetHash ) as any;
          if ( $hashElt.length > 0 ) {
            ( $( document as unknown as Element ) as any ).scrollTop( $hashElt.offset( ).top );
          }
        }, 2000 );
      }
    }
  }, [] );

  const postIdentification = ( ) => {
    const input = $( ".id_tab input[name='taxon_name']" );
    const selectedTaxon = ( input.data( "uiAutocomplete" ) as any ).selectedItem;
    if ( selectedTaxon ) {
      addID?.( selectedTaxon, { body: content, nominate } );
      ( input as any ).trigger( "resetSelection" );
      ( input as any ).val( "" );
      ( input.data( "uiAutocomplete" ) as any ).selectedItem = null;
      updateEditorContent?.( "activity", "" );
      setNominateOnSubmit?.( false );
    }
  };

  const currentUserIcon = ( ) => (
    config ? (
      <div className="icon">
        <UserImage user={config.currentUser} />
      </div>
    ) : (
      <div className="icon"><div className="UserImage" /></div>
    )
  );

  const doneButton = ( ) => {
    if ( !config?.currentUser ) return null;
    return (
      <Button
        className="comment_id"
        bsSize="small"
        onClick={() => {
          if ( ( $( ".comment_tab" ) as any ).is( ":visible" ) ) {
            if ( content ) {
              addComment?.( content );
              updateEditorContent?.( "activity", "" );
            }
          } else {
            postIdentification( );
          }
        }}
      >
        { I18n.t( "done" ) }
      </Button>
    );
  };

  const reviewCheckbox = ( ) => {
    if ( !config?.currentUser ) return null;
    return (
      <OverlayTrigger
        placement="top"
        trigger={["hover", "focus"]}
        delayShow={1000}
        overlay={(
          <Tooltip id="mark-as-reviewed-tooltip">
            <span
              dangerouslySetInnerHTML={{ __html: I18n.t( "mark_as_reviewed_desc" ) }}
            />
          </Tooltip>
        )}
        container={$( "#wrapper.bootstrap" ).get( 0 )}
      >
        <div className="review">
          <label>
            <input
              type="checkbox"
              id="reviewed"
              name="reviewed"
              checked={_.includes( observation?.reviewed_by, config.currentUser.id )}
              onChange={() => {
                if ( ( $( "#reviewed" ) as any ).is( ":checked" ) ) {
                  review?.( );
                } else {
                  unreview?.( );
                }
              }}
            />
            { I18n.t( "mark_as_reviewed" ) }
          </label>
        </div>
      </OverlayTrigger>
    );
  };

  if ( !observation ) return <div />;

  const loggedIn = config && config.currentUser;
  const currentUserID = loggedIn && _.findLast( observation.identifications, ( i: any ) => (
    i.current && i.user && i.user.id === config!.currentUser.id
  ) );
  let activity = _.compact( ( observation.identifications || [] ).concat( observation.comments ) );
  activity = _.sortBy( activity, ( a: any ) => moment.parseZone( a.created_at ) );
  activity = addImplicitDisagreementsToActivity( activity );

  return (
    <div className="Activity">
      <h3>{ I18n.t( "activity" ) }</h3>
      <div className={`activity ${activity.length === 0 ? "empty" : ""}`}>
        { activity.map( ( item: any ) => (
          <ActivityItem
            key={`activity-${item.id}-${item.created_at}`}
            item={item}
            observation={observation}
            config={config}
            currentUserID={currentUserID}
            inlineEditing
            addID={addID}
            confirmDeleteID={confirmDeleteID}
            deleteComment={deleteComment}
            editComment={editComment}
            editID={editID}
            hideAgree={hideAgree}
            hideCategory={hideCategory}
            hideCompare={hideCompare}
            hideContent={hideContent}
            hideDisagreement={hideDisagreement}
            hideMenu={hideMenu}
            hideUserIcon={hideUserIcon}
            linkTarget={linkTarget}
            noTaxonLink={noTaxonLink}
            onClickCompare={onClickCompare}
            performOrOpenConfirmationModal={performOrOpenConfirmationModal}
            restoreID={restoreID}
            setFlaggingModalState={setFlaggingModalState}
            showHidden={showHidden}
            trustUser={trustUser}
            unhideContent={unhideContent}
            untrustUser={untrustUser}
            unvoteIdentification={unvoteIdentification}
            voteIdentification={voteIdentification}
            withdrawID={withdrawID}
            nominateIdentification={nominateIdentification}
            unnominateIdentification={unnominateIdentification}
          />
        ) ) }
      </div>
      { currentUserIcon( ) }
      <ActivityCreatePanelContainer
        key={`activity-create-panel-${observation.id}`}
        {...props}
      />
      { doneButton( ) }
      { reviewCheckbox( ) }
    </div>
  );
};

export default Activity;

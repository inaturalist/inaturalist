import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import {
  Button,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import moment from "moment-timezone";
import { addImplicitDisagreementsToActivity } from "../../../shared/util";
import UserImage from "../../../shared/components/user_image";
import ActivityItem from "./activity_item";
import ActivityCreatePanelContainer from "../containers/activity_create_panel_container";

class Activity extends React.Component {
  componentDidMount( ) {
    if ( window.location.hash ) {
      // I really wish this timeout wasn't necessary but without it Chrome just
      // seems to scroll back to the top. Note that $.scrollTo doesn't seem to
      // work in Safari.
      let targetHash = window.location.hash;
      if ( $( targetHash ).length === 0 ) {
        targetHash = _.replace( `activity_${targetHash.replace( "#", "" )}`, "-", "_" );
        targetHash = `#${targetHash}`;
      }
      const isFirefox = navigator.userAgent.toLowerCase( ).indexOf( "firefox" ) > -1;
      if ( isFirefox ) {
        $.scrollTo( targetHash );
      } else {
        setTimeout( ( ) => {
          const $hashElt = $( targetHash );
          if ( $hashElt.length > 0 ) {
            $( document ).scrollTop( $hashElt.offset( ).top );
          }
        }, 2000 );
      }
    }
  }

  currentUserIcon( ) {
    const { config } = this.props;
    return config ? (
      <div className="icon">
        <UserImage user={config.currentUser} />
      </div>
    ) : (
      <div className="icon"><div className="UserImage" /></div>
    );
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

  doneButton( ) {
    const {
      addComment,
      config,
      content,
      updateEditorContent
    } = this.props;
    return config && config.currentUser ? (
      <Button
        className="comment_id"
        bsSize="small"
        onClick={
          ( ) => {
            if ( $( ".comment_tab" ).is( ":visible" ) ) {
              const comment = content;
              if ( comment ) {
                addComment( comment );
                updateEditorContent( "activity", "" );
              }
            } else {
              this.postIdentification( );
            }
          }
        }
      >
        { I18n.t( "done" ) }
      </Button> ) : null;
  }

  review( ) {
    const {
      observation,
      config,
      review,
      unreview
    } = this.props;
    return config && config.currentUser && (
      <OverlayTrigger
        placement="top"
        trigger={["hover", "focus"]}
        delayShow={1000}
        overlay={(
          <Tooltip id="mark-as-reviewed-tooltip">
            <span
              dangerouslySetInnerHTML={{
                __html: I18n.t( "mark_as_reviewed_desc" )
              }}
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
              checked={_.includes( observation.reviewed_by, config.currentUser.id )}
              onChange={( ) => {
                if ( $( "#reviewed" ).is( ":checked" ) ) {
                  review( );
                } else {
                  unreview( );
                }
              }}
            />
            { I18n.t( "mark_as_reviewed" ) }
          </label>
        </div>
      </OverlayTrigger>
    );
  }

  render( ) {
    const {
      observation,
      config
    } = this.props;
    if ( !observation ) { return ( <div /> ); }
    const loggedIn = config && config.currentUser;
    const currentUserID = loggedIn && _.findLast( observation.identifications, i => (
      i.current && i.user && i.user.id === config.currentUser.id
    ) );
    let activity = _.compact( ( observation.identifications || [] )
      .concat( observation.comments ) );
    activity = _.sortBy( activity, a => ( moment.parseZone( a.created_at ) ) );
    // attempting to match the logic in the computervision/score_observation endpoint
    // so we don't attempt to fetch vision results for obs which will have no results
    activity = addImplicitDisagreementsToActivity( activity );
    return (
      <div className="Activity">
        <h3>{ I18n.t( "activity" ) }</h3>
        <div className={`activity ${activity.length === 0 ? "empty" : ""}`}>
          { activity.map( item => (
            <ActivityItem
              key={`activity-${item.id}-${item.created_at}`}
              item={item}
              currentUserID={currentUserID}
              inlineEditing
              {...this.props}
            />
          ) ) }
        </div>
        { this.currentUserIcon( ) }
        <ActivityCreatePanelContainer
          key={`activity-create-panel-${observation.id}`}
          {...this.props}
        />
        { this.doneButton( ) }
        { this.review( ) }
      </div>
    );
  }
}

Activity.propTypes = {
  observation: PropTypes.object,
  config: PropTypes.object,
  observation_places: PropTypes.object,
  addComment: PropTypes.func,
  addID: PropTypes.func,
  content: PropTypes.string,
  createFlag: PropTypes.func,
  deleteComment: PropTypes.func,
  editComment: PropTypes.func,
  deleteFlag: PropTypes.func,
  deleteID: PropTypes.func,
  confirmDeleteID: PropTypes.func,
  editID: PropTypes.func,
  restoreID: PropTypes.func,
  review: PropTypes.func,
  setFlaggingModalState: PropTypes.func,
  unreview: PropTypes.func,
  onClickCompare: PropTypes.func,
  trustUser: PropTypes.func,
  untrustUser: PropTypes.func,
  updateEditorContent: PropTypes.func,
  showHidden: PropTypes.func
};

export default Activity;

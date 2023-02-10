import { connect } from "react-redux";
import { setConfig } from "../../../shared/ducks/config";
import { showModeratorActionForm } from "../../../shared/ducks/moderator_actions";
import ActivityItem from "../../show/components/activity_item";
import {
  addID,
  fetchCurrentObservation,
  loadingDiscussionItem,
  stopLoadingDiscussionItem,
  deleteComment,
  updateIdentification
} from "../actions";
import { setFlaggingModalState } from "../../show/ducks/flagging_modal";

function mapStateToProps( state, ownProps ) {
  return {
    config: state.config,
    currentUserID: ( ownProps.observation.identifications || [] ).find(
      ident => ident.user.id === state.config.currentUser.id && ident.current
    ),
    hideCompare: true,
    hideDisagreement: state.config.blind,
    hideCategory: state.config.blind,
    noTaxonLink: state.config.blind,
    linkTarget: "_blank"
  };
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    addID: ( taxon, options ) => dispatch( addID( taxon, ownProps.observation, options ) ),
    deleteComment: id => {
      const comment = { id, className: "Comment" };
      dispatch( loadingDiscussionItem( comment ) );
      dispatch( deleteComment( { id } ) )
        .catch( ( ) => {
          dispatch( stopLoadingDiscussionItem( comment ) );
        } )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ) );
        } );
    },
    withdrawID: id => {
      const ident = { id, className: "Identification" };
      const updateIdent = { id, identification: { current: false } };
      if ( id.toString( ).match( /A-z/ ) ) {
        ident.uuid = id;
        delete ident.id;
        updateIdent.uuid = id;
        delete updateIdent.id;
      }
      dispatch( loadingDiscussionItem( ident ) );
      dispatch( updateIdentification( updateIdent ) )
        .catch( ( ) => {
          dispatch( stopLoadingDiscussionItem( ident ) );
        } )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ) );
        } );
    },
    restoreID: id => {
      const ident = { id, className: "Identification" };
      const updateIdent = { id, identification: { current: true } };
      if ( id.toString( ).match( /A-z/ ) ) {
        ident.uuid = id;
        delete ident.id;
        updateIdent.uuid = id;
        delete updateIdent.id;
      }
      dispatch( loadingDiscussionItem( ident ) );
      dispatch( updateIdentification( updateIdent ) )
        .catch( ( ) => {
          dispatch( stopLoadingDiscussionItem( ident ) );
        } )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ) );
        } );
    },
    setFlaggingModalState: newState => {
      dispatch( setFlaggingModalState( newState ) );
    },
    showHidden: ( ) => dispatch( setConfig( { showHidden: true } ) ),
    hideContent: item => dispatch( showModeratorActionForm( item ) ),
    unhideContent: item => dispatch( showModeratorActionForm( item, "unhide" ) )
  };
}

const ActivityItemContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ActivityItem );

export default ActivityItemContainer;

import { connect } from "react-redux";
import Activity from "../components/activity";
import {
  addComment, confirmDeleteComment, editComment,
  addID, withdrawID, confirmDeleteID, editID, restoreID,
  review, unreview
} from "../ducks/observation";
import { setFlaggingModalState } from "../ducks/flagging_modal";
import { createFlag, deleteFlag } from "../ducks/flags";
import {
  fetchSuggestions,
  updateWithObservation as updateSuggestionsWithObservation
} from "../../identify/ducks/suggestions";
import {
  showCurrentObservation as showObservationModal
} from "../../identify/actions/current_observation_actions";
import { trustUser, untrustUser, setConfig } from "../../../shared/ducks/config";
import { showModeratorActionForm } from "../../../shared/ducks/moderator_actions";
import { updateEditorContent } from "../../shared/ducks/text_editors";

function mapStateToProps( state ) {
  const observation = Object.assign( {}, state.observation, {
    places: state.observationPlaces
  } );
  return {
    observation,
    config: state.config,
    content: state.textEditor.activity
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setFlaggingModalState: newState => {
      dispatch( setFlaggingModalState( newState ) );
    },
    addComment: body => { dispatch( addComment( body ) ); },
    deleteComment: id => { dispatch( confirmDeleteComment( id ) ); },
    editComment: ( id, body ) => { dispatch( editComment( id, body ) ); },
    addID: ( taxon, options ) => { dispatch( addID( taxon, options ) ); },
    withdrawID: uuid => { dispatch( withdrawID( uuid ) ); },
    confirmDeleteID: uuid => { dispatch( confirmDeleteID( uuid ) ); },
    editID: ( uuid, body ) => { dispatch( editID( uuid, body ) ); },
    restoreID: uuid => { dispatch( restoreID( uuid ) ); },
    createFlag: ( className, id, flag, body ) => {
      dispatch( createFlag( className, id, flag, body ) );
    },
    deleteFlag: id => { dispatch( deleteFlag( id ) ); },
    review: ( ) => { dispatch( review( ) ); },
    unreview: ( ) => { dispatch( unreview( ) ); },
    onClickCompare: ( e, taxon, observation ) => {
      const newObs = Object.assign( {}, observation, { taxon } );
      dispatch( updateSuggestionsWithObservation( newObs ) );
      dispatch( fetchSuggestions( ) );
      dispatch( showObservationModal( observation ) );
      e.preventDefault( );
      return false;
    },
    trustUser: user => {
      dispatch( trustUser( user ) );
    },
    untrustUser: user => {
      dispatch( untrustUser( user ) );
    },
    showHidden: ( ) => dispatch( setConfig( { showHidden: true } ) ),
    hideContent: item => dispatch( showModeratorActionForm( item, "hide" ) ),
    unhideContent: item => dispatch( showModeratorActionForm( item, "unhide" ) ),
    updateEditorContent: ( editor, content ) => dispatch( updateEditorContent( editor, content ) )
  };
}

const ActivityContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Activity );

export default ActivityContainer;

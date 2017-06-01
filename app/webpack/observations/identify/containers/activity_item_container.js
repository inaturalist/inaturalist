import { connect } from "react-redux";
import ActivityItem from "../../show/components/activity_item";
import {
  postIdentification,
  fetchCurrentObservation,
  loadingDiscussionItem,
  fetchObservationsStats,
  fetchIdentifiers,
  stopLoadingDiscussionItem,
  submitIdentificationWithConfirmation,
  deleteComment,
  deleteIdentification,
  updateIdentification
} from "../actions";
import { setFlaggingModalState } from "../../show/ducks/flagging_modal";

function mapStateToProps( state, ownProps ) {
  return {
    config: state.config,
    currentUserID: ownProps.observation.identifications.find( ident =>
      ident.user.id === state.config.currentUser.id && ident.current ),
    hideCompare: true
  };
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    addID: ( identification, options ) => {
      if ( options.agreeWith ) {
        const params = {
          taxon_id: identification.taxon.id,
          observation_id: identification.observation_id
        };
        dispatch( loadingDiscussionItem( identification ) );
        dispatch( postIdentification( params ) )
          .catch( ( ) => {
            dispatch( stopLoadingDiscussionItem( identification ) );
          } )
          .then( ( ) => {
            dispatch( fetchCurrentObservation( ) ).then( ( ) => {
              $( ".ObservationModal:first" ).find( ".sidebar" ).scrollTop( $( window ).height( ) );
            } );
            dispatch( fetchObservationsStats( ) );
            dispatch( fetchIdentifiers( ) );
          } );
      } else {
        const ident = Object.assign( { }, identification, {
          observation: ownProps.observation
        } );
        dispatch( submitIdentificationWithConfirmation( ident, {
          confirmationText: options.confirmationText
        } ) );
      }
    },
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
    deleteID: id => {
      const ident = { id, className: "Identification" };
      dispatch( loadingDiscussionItem( ident ) );
      dispatch( deleteIdentification( ident ) )
        .catch( ( ) => {
          dispatch( stopLoadingDiscussionItem( ident ) );
        } )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ) );
        } );
    },
    restoreID: id => {
      const ident = { id, className: "Identification" };
      dispatch( loadingDiscussionItem( ident ) );
      dispatch( updateIdentification( { id, current: true } ) )
        .catch( ( ) => {
          dispatch( stopLoadingDiscussionItem( ident ) );
        } )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ) );
        } );
    },
    setFlaggingModalState: ( newState ) => { dispatch( setFlaggingModalState( newState ) ); }
  };
}

const ActivityItemContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ActivityItem );

export default ActivityItemContainer;

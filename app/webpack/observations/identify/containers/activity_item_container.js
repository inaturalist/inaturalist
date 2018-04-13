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
    currentUserID: ( ownProps.observation.identifications || [] ).find( ident =>
      ident.user.id === state.config.currentUser.id && ident.current ),
    hideCompare: true,
    hideDisagreement: state.config.blind,
    hideCategory: state.config.blind,
    noTaxonLink: state.config.blind,
    linkTarget: "_blank"
  };
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    addID: ( taxon, options ) => {
      if ( options.agreedWith ) {
        const params = {
          taxon_id: options.agreedWith.taxon.id,
          observation_id: options.agreedWith.observation_id
        };
        dispatch( loadingDiscussionItem( options.agreedWith ) );
        dispatch( postIdentification( params ) )
          .catch( ( ) => {
            dispatch( stopLoadingDiscussionItem( options.agreedWith ) );
          } )
          .then( ( ) => {
            dispatch( fetchCurrentObservation( ) ).then( ( ) => {
              $( ".ObservationModal:first" ).find( ".sidebar" ).scrollTop( $( window ).height( ) );
            } );
            dispatch( fetchObservationsStats( ) );
            dispatch( fetchIdentifiers( ) );
          } );
      } else {
        const ident = {
          taxon_id: taxon.id,
          observation_id: ownProps.observation.id
        };
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

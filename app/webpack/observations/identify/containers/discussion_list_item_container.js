import { connect } from "react-redux";
import DiscussionListItem from "../components/discussion_list_item";
import {
  postIdentification,
  fetchCurrentObservation,
  loadingDiscussionItem,
  fetchObservationsStats,
  fetchIdentifiers,
  stopLoadingDiscussionItem
} from "../actions";

function mapStateToProps( state, ownProps ) {
  if ( ownProps.hideAgree === null ) {
    const hideAgree = ownProps.identification &&
      ownProps.identification.current &&
      state.config.currentUser &&
      state.config.currentUser.id === ownProps.identification.user.id;
    return {
      hideAgree,
      currentUser: state.config.currentUser,
      loading: ownProps.identification ? ownProps.identification.loading : false
    };
  }
  return {
    currentUser: state.config.currentUser,
    loading: ownProps.identification ? ownProps.identification.loading : false
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    agreeWith: ( identification ) => {
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
    }
  };
}

const DiscussionListItemContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( DiscussionListItem );

export default DiscussionListItemContainer;

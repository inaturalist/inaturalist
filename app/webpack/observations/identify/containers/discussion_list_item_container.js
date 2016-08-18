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
      loading: state.currentObservation.loadingDiscussionItem
    };
  }
  return {
    currentUser: state.config.currentUser,
    loading: state.currentObservation.loadingDiscussionItem
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    agreeWith: ( params ) => {
      dispatch( loadingDiscussionItem( ) );
      dispatch( postIdentification( params ) )
        .catch( ( ) => {
          dispatch( stopLoadingDiscussionItem( ) );
        } )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ) );
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

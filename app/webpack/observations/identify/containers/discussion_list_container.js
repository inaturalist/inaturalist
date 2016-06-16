import { connect } from "react-redux";
import DiscussionList from "../components/discussion_list";
import {
  fetchCurrentObservation,
  loadingDiscussionItem,
  stopLoadingDiscussionItem,
  deleteIdentification,
  deleteComment
} from "../actions";

function mapStateToProps( ) {
  return { };
}

function mapDispatchToProps( dispatch ) {
  return {
    onDelete: ( item ) => {
      dispatch( loadingDiscussionItem( ) );
      if ( item.className === "Identification" ) {
        dispatch( deleteIdentification( item ) )
          .catch( ( ) => {
            dispatch( stopLoadingDiscussionItem( ) );
          } )
          .then( ( ) => {
            dispatch( fetchCurrentObservation( ) );
          } );
      } else {
        dispatch( deleteComment( item ) )
          .then( ( ) => {
            dispatch( fetchCurrentObservation( ) );
          } );
      }
    }
  };
}

const DiscussionListContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( DiscussionList );

export default DiscussionListContainer;

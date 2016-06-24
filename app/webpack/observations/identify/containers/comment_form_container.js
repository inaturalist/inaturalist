import { connect } from "react-redux";
import CommentForm from "../components/comment_form";
import {
  postComment,
  fetchCurrentObservation,
  loadingDiscussionItem,
  stopLoadingDiscussionItem
} from "../actions";

// ownProps contains data passed in through the "tag", so in this case
// <CommentFormContainer observation={foo} />
function mapStateToProps( state, ownProps ) {
  return {
    observation: ownProps.observation
  };
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    onSubmitComment: ( comment ) => {
      dispatch( loadingDiscussionItem( ) );
      dispatch( postComment( comment ) )
        .catch( ( ) => {
          dispatch( stopLoadingDiscussionItem( ) );
        } )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ownProps.observation ) );
        } );
    }
  };
}

const CommentFormContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CommentForm );

export default CommentFormContainer;

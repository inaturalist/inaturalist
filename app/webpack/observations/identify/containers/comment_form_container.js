import { connect } from "react-redux";
import CommentForm from "../components/comment_form";
import {
  postComment,
  fetchCurrentObservation,
  loadingDiscussionItem,
  stopLoadingDiscussionItem
} from "../actions";
import { updateEditorContent } from "../../shared/ducks/text_editors";

// ownProps contains data passed in through the "tag", so in this case
// <CommentFormContainer observation={foo} />
function mapStateToProps( state, ownProps ) {
  return {
    observation: ownProps.observation,
    content: state.textEditor.obsIdentifyIdComment
  };
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    onSubmitComment: comment => {
      dispatch( loadingDiscussionItem( comment ) );
      dispatch( postComment( comment ) )
        .catch( ( ) => {
          dispatch( stopLoadingDiscussionItem( comment ) );
        } )
        .then( ( ) => {
          dispatch( updateEditorContent( "obsIdentifyIdComment", "" ) );
          dispatch( fetchCurrentObservation( ownProps.observation ) ).then( ( ) => {
            $( ".ObservationModal:first" ).find( ".sidebar" ).scrollTop( $( window ).height( ) );
          } );
        } );
    },
    updateEditorContent: ( editor, content ) => {
      dispatch( updateEditorContent( editor, content ) );
    }
  };
}

const CommentFormContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CommentForm );

export default CommentFormContainer;

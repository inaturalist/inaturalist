import inatjs from "inaturalistjs";
import { showAlert } from "./alert_actions";

const POST_COMMENT = "post_comment";

function postComment( params ) {
  return function ( dispatch ) {
    const body = Object.assign( {}, params );
    // TODO handle error state
    return inatjs.comments.create( body ).catch( e => {
      dispatch( showAlert(
        I18n.t( "failed_to_save_recoed" ),
        { title: I18n.t( "request_failed" ) }
      ) );
      throw e;
    } );
  };
}

function deleteComment( comment ) {
  return function ( ) {
    return inatjs.comments.delete( comment );
  };
}

export {
  postComment,
  POST_COMMENT,
  deleteComment
};

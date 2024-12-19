import inatjs from "inaturalistjs";
import { showAlert } from "../../../shared/ducks/alert_modal";
import { parseRailsErrorsResponse } from "../../../shared/util";

const POST_COMMENT = "post_comment";

function postComment( params ) {
  return function ( dispatch ) {
    // TODO handle error state
    const payload = {
      comment: params
    };
    return inatjs.comments.create( payload ).catch( e => {
      e.response.text( ).then( text => {
        const railsErrors = parseRailsErrorsResponse( text ) || [I18n.t( "failed_to_save_record" )];
        dispatch( showAlert(
          railsErrors.join( "," ),
          { title: I18n.t( "request_failed" ) }
        ) );
      } ).catch( ( ) => {
        dispatch( showAlert(
          I18n.t( "failed_to_save_record" ),
          { title: I18n.t( "request_failed" ) }
        ) );
      } );
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

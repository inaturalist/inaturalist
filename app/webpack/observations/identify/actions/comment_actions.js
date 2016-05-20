import inatjs from "inaturalistjs";

const POST_COMMENT = "post_comment";

function postComment( params ) {
  return function ( ) {
    const body = Object.assign( {}, params );
    // TODO handle error state
    return inatjs.comments.create( body );
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

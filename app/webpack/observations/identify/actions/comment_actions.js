import inatjs from "inaturalistjs";

const POST_COMMENT = "post_comment";

function postComment( params ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const body = Object.assign( {}, params );
    inatjs.comments.create( body )
      .then( response => {
        console.log( "[DEBUG] response: ", response );
      } );
  };
}

export {
  postComment,
  POST_COMMENT
};

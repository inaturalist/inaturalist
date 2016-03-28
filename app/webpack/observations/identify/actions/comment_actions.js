import inatjs from "inaturalistjs";

const POST_COMMENT = "post_comment";

function postComment( params ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const body = Object.assign( {}, params );
    body.authenticity_token = s.config.csrfToken;
    body.user_id = 1;
    inatjs.comments.create( body, { same_origin: true } )
      .then( response => {
        console.log( "[DEBUG] response: ", response );
      } );
  };
}

export {
  postComment,
  POST_COMMENT
};

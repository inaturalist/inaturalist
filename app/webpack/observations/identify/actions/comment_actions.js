import inatjs from "inaturalistjs";

const POST_COMMENT = "post_comment";

function postComment( params ) {
  return function ( ) {
  // return function ( dispatch, getState ) {
    // const s = getState();
    // const options = {
    //   api_token: s.config.apiToken
    // };
    // console.log( "[DEBUG] options: ", options );
    const body = Object.assign( {}, params );
    // TODO handle error state
    return inatjs.comments.create( body )
      .then( response => {
        console.log( "[DEBUG] response: ", response );
      } );
  };
}

export {
  postComment,
  POST_COMMENT
};

import fetch from "isomorphic-fetch";

const POST_COMMENT = "post_comment";

function postComment( params ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const body = Object.assign( {}, params );
    body[s.config.csrfParam] = s.config.csrfToken;
    body.user_id = 1;
    return fetch( "/comments.json", {
      method: "post",
      credentials: "same-origin", // sends cookies so rails can check them against the CSRF token
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json"
      },
      body: JSON.stringify( body )
    } )
      .then( response => ( response.json( ) ) )
      .then( json => {
        // TODO dispatch an action to refresh only that observation
        console.log( "[DEBUG] json: ", json );
      } );
  };
}

export {
  postComment,
  POST_COMMENT
};

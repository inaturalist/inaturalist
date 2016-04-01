import inatjs from "inaturalistjs";

const POST_IDENTIFICATION = "post_identification";

function postIdentification( params ) {
  return function ( dispatch, getState ) {
    const s = getState();
    const body = Object.assign( {}, params );
    body.authenticity_token = s.config.csrfToken;
    body.user_id = 1;
    inatjs.identification.create( body, { same_origin: true } )
      .then( response => {
        console.log( "[DEBUG] response: ", response );
      } );
  };
}

export {
  postIdentification,
  POST_IDENTIFICATION
};

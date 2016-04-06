import inatjs from "inaturalistjs";

const POST_IDENTIFICATION = "post_identification";

function postIdentification( params ) {
  return function ( ) {
    const body = Object.assign( {}, params );
    body.user_id = 1;
    return inatjs.identifications.create( body )
      .then( response => {
        console.log( "[DEBUG] response: ", response );
      } );
  };
}

export {
  postIdentification,
  POST_IDENTIFICATION
};

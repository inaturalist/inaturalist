import fetch from "isomorphic-fetch";

const NodeAPI = class ObsCard {
  static fetch( path ) {
    return fetch( `http://api.inaturalist.org/v1/${path}`, { method: "GET" } ).
      then( response => {
        if ( response.status >= 200 && response.status < 300 ) {
          return response;
        } else {
          const error = new Error( response.statusText );
          error.response = response;
          throw error;
        } } ).
      then( response => response.text( ) ).
      then( text => {
        if ( text ) { return JSON.parse( text ); }
        return text;
      } );
  }
};

export default NodeAPI;

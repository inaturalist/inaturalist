import fetch from "isomorphic-fetch";

const Util = class ObsCard {
  static nodeApiFetch( path ) {
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

  static numberWithCommas( num ) {
    if ( !num && num !== 0 ) { return ""; }
    return Number( num ).toLocaleString( );
  }
};

export default Util;

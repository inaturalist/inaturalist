import fetch from "isomorphic-fetch";

const util = class util {

  static isOnline( callback ) {
    // temporary until we have a ping API
    fetch( "/pages/about", {
      method: "head",
      mode: "no-cors",
      cache: "no-store" } ).
    then( ( ) => callback( true ) ).
    catch( ( ) => callback( false ) );
  }

};

export default util;

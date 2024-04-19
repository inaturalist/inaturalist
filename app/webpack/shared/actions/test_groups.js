import _ from "lodash";
import { updateCurrentUser } from "../ducks/config";

function toggleGroup( group ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser ) {
      return;
    }
    const { currentUser } = state.config;
    currentUser.testGroups = currentUser.testGroups || [];
    const userInGroup = currentUser.testGroups.indexOf( group ) >= 0;

    const csrfParam = $( "meta[name=csrf-param]" ).attr( "content" );
    const csrfToken = $( "meta[name=csrf-token]" ).attr( "content" );

    const body = new FormData( );
    body.append( csrfParam, csrfToken );
    const fetchOpts = {
      method: "put",
      credentials: "same-origin",
      body
    };
    const path = userInGroup
      ? `/users/${currentUser.id}/leave_test?test=${group}`
      : `/users/${currentUser.id}/join_test?test=${group}`;
    fetch( path, fetchOpts ).then( ( ) => {
      const newTestGroups = userInGroup
        ? _.without( currentUser.testGroups, group )
        : _.uniq( currentUser.testGroups.concat( [group] ) );
      dispatch( updateCurrentUser( { testGroups: newTestGroups } ) );
    } ).catch( e => {
      alert( e );
    } );
  };
}

export {
  toggleGroup
};

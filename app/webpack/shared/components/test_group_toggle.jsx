import React from "react";
import PropTypes from "prop-types";

const TestGroupToggle = ( {
  group,
  joinPrompt,
  joinedStatus,
  user
} ) => {
  if ( !user ) {
    return <div />;
  }
  const csrfParam = $( "meta[name=csrf-param]" ).attr( "content" );
  const csrfToken = $( "meta[name=csrf-token]" ).attr( "content" );

  const userInGroup = user.testGroups && user.testGroups.indexOf( group ) >= 0;
  const toggleGroup = ( ) => {
    const body = new FormData( );
    body.append( csrfParam, csrfToken );
    const fetchOpts = {
      method: "put",
      credentials: "same-origin",
      body
    };
    let path = `/users/${user.id}/join_test?test=${group}`;
    if ( userInGroup ) {
      path = `/users/${user.id}/leave_test?test=${group}`;
    }
    return fetch( path, fetchOpts ).then( response => {
      if ( response.status >= 200 && response.status < 300 ) {
        location.reload( );
      } else {
        throw new Error( "there was a problem leaving the test group" );
      }
    } ).catch( e => {
      alert( e );
    } );
  };
  return (
    <div className="TestGroupToggle alert alert-warning text-center">
      { userInGroup ? (
        <div>
          { joinedStatus }
          &nbsp;
          <button className="btn btn-warning" onClick={ ( ) => toggleGroup( ) }>
            { I18n.t( "stop_testing" ) }
          </button>
        </div>
      ) : (
        <div>
          { joinPrompt }
          <button className="btn btn-success" onClick={ ( ) => toggleGroup( ) } style={{ marginLeft: "0.5em" }}>
            { I18n.t( "yes" ) }
          </button>
        </div>
      ) }
    </div>
  );
};

TestGroupToggle.propTypes = {
  group: PropTypes.string.isRequired,
  joinPrompt: PropTypes.string.isRequired,
  joinedStatus: PropTypes.string.isRequired,
  user: PropTypes.object
};

export default TestGroupToggle;

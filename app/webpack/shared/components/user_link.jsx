import React from "react";
import PropTypes from "prop-types";

const UserLink = ( { user, useName } ) => {
  if ( !user ) { return null; }
  let displayName = user.login;
  if ( useName && user.name && user.name.length > 0 ) {
    displayName = user.name;
  }
  return (
    <a
      className="userlink"
      href={`/people/${user.login || user.id}`}
      title={displayName}
    >
      { displayName }
    </a>
  );
};

UserLink.propTypes = {
  user: PropTypes.object,
  useName: PropTypes.bool
};

export default UserLink;

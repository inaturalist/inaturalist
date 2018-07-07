import React from "react";
import PropTypes from "prop-types";

const UserLink = ( { user } ) => {
  if ( !user ) { return null; }
  return (
    <a
      className="userlink"
      href={`/people/${user.login || user.id}`}
      title={user.login}
    >
      { user.login }
    </a>
  );
};

UserLink.propTypes = {
  user: PropTypes.object
};

export default UserLink;

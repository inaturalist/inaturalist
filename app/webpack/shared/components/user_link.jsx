import React from "react";
import PropTypes from "prop-types";

import Inativersary from "./inativersary";

const UserLink = ( {
  className,
  noInativersary,
  target,
  uniqueKey,
  user,
  useName
} ) => {
  if ( !user ) { return null; }
  let displayName = user.login;
  if ( useName && user.name && user.name.length > 0 ) {
    displayName = user.name;
  }
  return (
    <span className="userlink">
      <a
        className={className}
        href={`/people/${user.login || user.id}`}
        rel={target === "_blank" ? "noopener noreferrer" : null}
        target={target}
        title={displayName}
      >
        { displayName }
      </a>
      { !noInativersary && <Inativersary uniqueKey={uniqueKey} user={user} /> }
    </span>
  );
};

UserLink.propTypes = {
  className: PropTypes.string,
  noInativersary: PropTypes.bool,
  target: PropTypes.string,
  uniqueKey: PropTypes.string,
  useName: PropTypes.bool,
  user: PropTypes.object
};

export default UserLink;

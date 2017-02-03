import React, { PropTypes } from "react";
import UserImage from "../../identify/components/user_image.jsx";


const UserWithIcon = ( { user } ) => {
  if ( !user ) { return ( <div /> ); }
  return (
    <div className="UserWithIcon">
      <div className="icon">
        <UserImage user={ user } />
      </div>
      <div className="title">
        <a href={ `/people/${user.login}` }>{ user.login }</a>
      </div>
      <div className="subtitle">
        <a href={ `/observations?user_id=${user.login}` }>
          <i className="fa fa-binoculars" />
          { user.observations_count } observations
        </a>
      </div>
    </div>
  );
};

UserWithIcon.propTypes = {
  user: PropTypes.object
};

export default UserWithIcon;

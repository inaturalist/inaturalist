import React, { PropTypes } from "react";
import UserImage from "../../../shared/components/user_image";

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
        <a href={ `/observations?user_id=${user.login}&place_id=any&verifiable=any` }>
          <i className="fa fa-binoculars" />
          { I18n.t( "x_observations", { count: user.observations_count.toLocaleString( ) } ) }
        </a>
      </div>
    </div>
  );
};

UserWithIcon.propTypes = {
  user: PropTypes.object
};

export default UserWithIcon;

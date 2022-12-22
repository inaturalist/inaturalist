import React from "react";
import PropTypes from "prop-types";

import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";

const MonthlySupporters = ( { data } ) => {
  const slicedData = data.slice( 0, 22 ).map(
    user => ( { ...user, icon_url: user.icon_url.replace( "staticdev", "static" ) } )
  );
  return (
    <div className="MonthlySupporters">
      <div className="supporters">
        { slicedData.map( ( user, i ) => (
          <div
            className={`monthly-supporter ${i >= 9 ? "hidden-xs" : ""}`}
            key={`monthly-supporters-user-${user.login}`}
          >
            <UserImage user={user} />
            <UserLink user={user} useName />
          </div>
        ) ) }
      </div>
    </div>
  );
};

MonthlySupporters.propTypes = {
  data: PropTypes.array
};

export default MonthlySupporters;

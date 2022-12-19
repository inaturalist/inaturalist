import React from "react";
import PropTypes from "prop-types";

import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";

const MonthlySupporters = ( { year, data } ) => {
  console.log( "data: ", data );
  const slicedData = data.slice( 25 ).map(
    user => ( { ...user, icon_url: user.icon_url.replace( "staticdev", "static" ) } )
  );
  console.log( "slicedData: ", slicedData );
  return (
    <div className="Donors">
      <h4>
        <a name="monthly-supporters" href="#monthly-supporters">
          <span>{I18n.t( "views.stats.year.monthly_supporters" )}</span>
        </a>
      </h4>
      { slicedData.map( user => (
        <div key={`monthly-supporters-user-${user.login}`}>
          <UserImage user={user} />
          <UserLink user={user} />
        </div>
      ) ) }
    </div>
  );
};

MonthlySupporters.propTypes = {
  year: PropTypes.number,
  data: PropTypes.array
};

export default MonthlySupporters;

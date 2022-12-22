import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";

import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";

const MonthlySupporters = ( { data } ) => {
  const slicedData = _.shuffle( data ).slice( 0, 22 ).map(
    user => ( { ...user, icon_url: user.icon_url.replace( "staticdev", "static" ) } )
  );
  return (
    <div className="MonthlySupporters">
      <div className="supporters">
        { slicedData.map( ( user, i ) => {
          let hiddenClass = "";
          if ( i >= 18 ) {
            hiddenClass += " hidden-md";
          }
          if ( i >= 16 ) {
            hiddenClass += " hidden-sm";
          }
          if ( i >= 9 ) {
            hiddenClass += " hidden-xs";
          }
          return (
            <div
              className={`monthly-supporter ${hiddenClass}`}
              key={`monthly-supporters-user-${user.login}`}
            >
              <UserImage user={user} />
              <UserLink user={user} useName />
            </div>
          );
        } ) }
      </div>
    </div>
  );
};

MonthlySupporters.propTypes = {
  data: PropTypes.array
};

export default MonthlySupporters;

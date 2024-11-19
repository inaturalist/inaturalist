import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";

import UserImage from "../../../shared/components/user_image";
import UserLink from "../../../shared/components/user_link";

const MonthlySupporters = ( { data } ) => {
  // Just don't show anything if the text isn't translated
  if (
    !I18n.locale.match( /^en/ )
    && (
      I18n.t( "yir_monthly_supporters_random_selection" )
      === I18n.t( "yir_monthly_supporters_random_selection", { locale: "en" } )
    )
  ) {
    return <span />;
  }
  const slicedData = _.shuffle( data ).slice( 0, 22 ).map(
    user => ( { ...user, icon_url: user.icon_url.replace( "staticdev", "static" ) } )
  );
  return (
    <div className="MonthlySupporters">
      <p>
        { I18n.t( "yir_monthly_supporters_random_selection" ) }
      </p>
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

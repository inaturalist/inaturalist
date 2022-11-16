import React from "react";
import PropTypes from "prop-types";

const UserWithIcon = "../../../observations/show/components/user_with_icon";

const MonthlySupporters = ( { year, data } ) => (
  <div className="Donors">
    <h4>
      <a name="monthly-supporters" href="#monthly-supporters">
        <span>{I18n.t( "views.stats.year.monthly_supporters" )}</span>
      </a>
    </h4>
    { data.map( user => <UserWithIcon user={user} key={`monthly-supporter-${user.id}`} /> ) }
  </div>
);

MonthlySupporters.propTypes = {
  year: PropTypes.number,
  data: PropTypes.array
};

export default MonthlySupporters;

import React from "react";
import PropTypes from "prop-types";

const Account = ( { profile, setUserData } ) => {
  const handleInputChange = e => {
    const updatedProfile = profile;
    updatedProfile[e.target.name] = e.target.value;
    setUserData( updatedProfile );
  };

  return (
    <div className="col-xs-9">
      <div className="row">
        <div className="col-md-5 col-xs-10">
          <div className="profile-setting">
            <h5>{I18n.t( "place_geo.geo_planet_place_types.Time_Zone" )}</h5>
            <div>{I18n.t( "all_your_observations_will_default_this_time_zone" )}</div>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "language_slash_locale" )}</h5>
            <div>{I18n.t( "language_slash_locale_description" )}</div>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "default_search_place" )}</h5>
            <div>{I18n.t( "default_search_place_description" )}</div>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "privacy" )}</h5>
            <div>{I18n.t( "views.users.edit.prefers_no_tracking_label" )}</div>
          </div>
          <div className="profile-setting">
            <h5>{I18n.t( "danger_zone" )}</h5>
            <div>{I18n.t( "delete_your_account" )}</div>
          </div>
        </div>
        <div className="col-md-1" />
        <div className="col-md-6 col-xs-10">
          <div className="profile-setting">
            <h5>{I18n.t( "inaturalist_network_affiliation" )}</h5>
            {/* eslint-disable-next-line react/no-danger */}
            <span dangerouslySetInnerHTML={{
              __html: I18n.t( "views.users.edit.inaturalist_network_affiliation_desc_html", {
                url: "https://www.inaturalist.org/sites/network"
              } )
            }}
            />
          </div>
        </div>
      </div>
    </div>
  );
};

Account.propTypes = {
  profile: PropTypes.object,
  setUserData: PropTypes.func
};

export default Account;

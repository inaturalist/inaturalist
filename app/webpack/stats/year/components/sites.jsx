import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";

const Sites = ( {
  sites,
  site,
  defaultSiteId,
  year
} ) => {
  const visibleSites = _.filter( sites, s => s.id !== site.id && s.id !== defaultSiteId );
  return (
    (
      <div className="Sites">
        <h3>
          <a name="network" href="#network">
            <span>{I18n.t( "views.stats.year.inaturalist_network" )}</span>
          </a>
        </h3>
        <p className="text-muted">
          { I18n.t( "views.stats.year.inaturalist_network_desc" ) }
        </p>
        <div className="visible-sites">
          { visibleSites.map( s => (
            <div className="site" key={`site-${s.id}`}>
              <div className="site-icon">
                <a href={`${s.url}/stats/${year}`}>
                  <img alt={s.title} src={s.icon_url} className="img-responsive" />
                </a>
              </div>
              <div className="ribbon-container">
                <div className="ribbon">
                  <div className="ribbon-content">
                    <a href={`${s.url}/stats/${year}`}>{ s.name }</a>
                  </div>
                </div>
              </div>
            </div>
          ) ) }
        </div>
      </div>
    )
  );
};

Sites.propTypes = {
  sites: PropTypes.array,
  site: PropTypes.object,
  defaultSiteId: PropTypes.number,
  year: PropTypes.number.isRequired
};

Sites.defaultProps = {
  sites: [],
  site: {}
};

export default Sites;

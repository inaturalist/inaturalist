import _ from "lodash";
import moment from "moment-timezone";
import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";

const MoreFromUser = ( { observation, observations } ) => {
  if ( !observation || _.isEmpty( observations ) ) { return ( <div /> ); }
  let dateObserved;
  if ( observation.time_observed_at ) {
    dateObserved = moment.tz( observation.time_observed_at,
      observation.observed_time_zone );
  } else if ( observation.observed_on ) {
    dateObserved = moment( observation.observed_on );
  }
  const onDate = dateObserved ? dateObserved.format( "YYYY-MM-DD" ) : null;
  return (
    <div className="MoreFromUser">
      <h3>
        More from { observation.user.login }
        <div className="links">
          <a href={ `/observations?user_id=${observation.user.login}` }>
            View all
          </a>
          { dateObserved ? (
            <span>
              <span className="separator">·</span>
              <a href={ `/observations?user_id=${observation.user.login}&on=${onDate}` }>
                View all from { dateObserved.format( "MMMM D, YYYY" ) }
              </a>
            </span>
          ) : "" }
        </div>
      </h3>
      <div className="list">
        { observations.map( o => {
          let taxonJSX = I18n.t( "unknown" );
          if ( o.taxon && o.taxon !== null ) {
            taxonJSX = (
              <SplitTaxon taxon={o.taxon} url={`/observations/${o.id}`} />
            );
          }
          const iconicTaxonName = o.taxon ? o.taxon.iconic_taxon_name.toLowerCase( ) : "unknown";
          return (
            <div className="obs" key={ `more-obs-${o.id}` }>
              <div className="photo">
                <a
                  href={`/observations/${o.id}`}
                  style={ {
                    backgroundImage: o.photo( ) ? `url( '${o.photo( "medium" )}' )` : ""
                  } }
                  target="_self"
                  className={`${o.hasMedia( ) ? "" : "iconic"} ${o.hasSounds( ) ? "sound" : ""}`}
                >
                  <i className={ `icon icon-iconic-${iconicTaxonName}`} />
                  <i className="sound-icon fa fa-volume-up" />
                </a>
              </div>
              <div className="caption">
                { taxonJSX }
              </div>
            </div>
          );
        } ) }
      </div>
    </div>
  );
};

MoreFromUser.propTypes = {
  observation: PropTypes.object,
  observations: PropTypes.array
};

export default MoreFromUser;

import _ from "lodash";
import moment from "moment-timezone";
import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";

const MoreFromUser = ( { observation, observations, showNewObservation } ) => {
  if ( !observation || _.isEmpty( observations ) ) { return ( <div /> ); }
  let dateObserved;
  if ( observation.time_observed_at ) {
    dateObserved = moment.tz( observation.time_observed_at,
      observation.observed_time_zone );
  } else if ( observation.observed_on ) {
    dateObserved = moment( observation.observed_on );
  }
  const onDate = dateObserved ? dateObserved.format( "YYYY-MM-DD" ) : null;
  const calendarDate = dateObserved ? dateObserved.format( "YYYY/M/D" ) : null;
  const loadObservationCallback = ( e, o ) => {
    if ( !e.metaKey ) {
      e.preventDefault( );
      showNewObservation( o );
    }
  };
  const userLogin = observation.user.login;
  return (
    <div className="MoreFromUser">
      <h3>
        <span dangerouslySetInnerHTML={ { __html:
          I18n.t( "more_from_x", { x: `<a href="/people/${userLogin}">${userLogin}</a>` } ) } }
        />
        <div className="links">
          <span className="view">{ I18n.t( "view" ) }:</span>
          <a href={ `/observations?user_id=${userLogin}&place_id=any` }>
            { I18n.t( "all" ) }
          </a>
          { dateObserved ? (
            <span>
              <span className="separator">·</span>
              <a href={ `/observations?user_id=${userLogin}&on=${onDate}&place_id=any` }>
                { dateObserved.format( "MMMM D, YYYY" ) }
              </a>
              <span className="separator">·</span>
              <a href={ `/calendar/${userLogin}/${calendarDate}` }>
                { I18n.t( "calendar" ) }
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
          const iconicTaxonName = o.taxon ? o.taxon.iconic_taxon_name.toLowerCase( ) :
            I18n.t( "unknown" );
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
                  onClick={ e => { loadObservationCallback( e, o ); } }
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
  observations: PropTypes.array,
  showNewObservation: PropTypes.func
};

export default MoreFromUser;

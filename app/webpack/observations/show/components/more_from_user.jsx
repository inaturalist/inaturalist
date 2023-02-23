import _ from "lodash";
import moment from "moment-timezone";
import React from "react";
import PropTypes from "prop-types";
import { Col } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";

const MoreFromUser = ( {
  observation,
  otherObservations,
  showNewObservation,
  config
} ) => {
  if (
    !observation
    || !observation.user
    || (
      _.isEmpty( otherObservations.earlierUserObservations )
      && _.isEmpty( otherObservations.laterUserObservations )
    )
  ) {
    return ( <div /> );
  }
  let dateObserved;
  if ( observation.time_observed_at ) {
    dateObserved = moment.tz( observation.time_observed_at,
      observation.observed_time_zone );
  } else if ( observation.observed_on ) {
    dateObserved = moment( observation.observed_on );
  }
  const onDate = dateObserved ? dateObserved.format( "YYYY-MM-DD" ) : null;
  const calendarDate = dateObserved ? dateObserved.format( "YYYY/M/D" ) : null;
  const { testingApiV2 } = config || {};
  const loadObservationCallback = ( e, o ) => {
    if ( !e.metaKey ) {
      e.preventDefault( );
      showNewObservation( o, { useInstance: !testingApiV2 } );
    }
  };
  const userLogin = observation.user.login;
  // obs list starts with the previous 3 obs
  let observations = _.take( otherObservations.earlierUserObservations, 3 );
  // reverse them since they are ordered DESC, and we want to show them ASC
  observations.reverse( );
  // add the next 3 obs
  observations = observations.concat( _.take( otherObservations.laterUserObservations, 3 ) );
  if ( observations.length < 6 ) {
    // if we don't have 6 yet, add the rest of the next obs
    observations = observations.concat( otherObservations.laterUserObservations.slice( 3 ) );
    observations = _.take( observations, 6 );
  }
  if ( observations.length < 6 ) {
    // if we don't have 6 yet, add as many more previous obs as we need
    const moreEarlier = _.take(
      otherObservations.earlierUserObservations.slice( 3 ), 6 - observations.length
    );
    moreEarlier.reverse( );
    observations = moreEarlier.concat( observations );
  }
  return (
    <div className="MoreFromUser">
      <Col xs={12}>
        <h3>
          <span
            dangerouslySetInnerHTML={{
              __html: I18n.t( "more_from_x", { x: `<a href="/people/${userLogin}">${userLogin}</a>` } )
            }}
          />
          <div className="links">
            <span className="view">{ I18n.t( "label_colon", { label: I18n.t( "view" )} ) }</span>
            <a href={`/observations?user_id=${userLogin}&place_id=any&verifiable=any`}>
              { I18n.t( "all" ) }
            </a>
            { dateObserved ? (
              <span>
                <span className="separator">·</span>
                <a href={`/observations?user_id=${userLogin}&on=${onDate}&place_id=any&verifiable=any`}>
                  { dateObserved.format( I18n.t( "momentjs.date_long" ) ) }
                </a>
                <span className="separator">·</span>
                <a href={`/calendar/${userLogin}/${calendarDate}`}>
                  { I18n.t( "calendar" ) }
                </a>
              </span>
            ) : "" }
          </div>
        </h3>
      </Col>
      <div className="list">
        { observations.map( o => {
          let taxonJSX = I18n.t( "unknown" );
          if ( o.taxon && o.taxon !== null ) {
            taxonJSX = (
              <SplitTaxon noParens taxon={o.taxon} url={`/observations/${o.id}`} user={config.currentUser} />
            );
          }
          const iconicTaxonName = o.taxon && o.taxon.iconic_taxon_name
            ? o.taxon.iconic_taxon_name.toLowerCase( )
            : "unknown";
          return (
            <Col xs={2} key={`more-obs-${o.uuid}`}>
              <div className="obs">
                <div className="photo">
                  <a
                    href={`/observations/${o.id}`}
                    style={o.photo( )
                      ? { backgroundImage: `url( '${o.photo( "medium" )}' )` }
                      : null
                    }
                    target="_self"
                    className={`${o.hasMedia( ) ? "" : "iconic"} ${o.hasSounds( ) ? "sound" : ""}`}
                    onClick={e => { loadObservationCallback( e, o ); }}
                  >
                    <i className={`taxon-image icon icon-iconic-${iconicTaxonName}`} />
                  </a>
                </div>
                <div className="caption">
                  { taxonJSX }
                </div>
              </div>
            </Col>
          );
        } ) }
      </div>
    </div>
  );
};

MoreFromUser.propTypes = {
  observation: PropTypes.object,
  otherObservations: PropTypes.object,
  showNewObservation: PropTypes.func,
  config: PropTypes.object
};

MoreFromUser.defaultProps = {
  config: {}
};

export default MoreFromUser;

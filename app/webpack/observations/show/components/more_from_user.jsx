import _ from "lodash";
import moment from "moment-timezone";
import React, { useRef } from "react";
import PropTypes from "prop-types";
import Carousel from "../../../shared/components/carousel";
import TaxonThumbnail from "../../../shared/components/taxon_thumbnail";

const MoreFromUser = ( {
  observation,
  otherObservations,
  showNewObservation,
  config
} ) => {
  const firstItemRef = useRef( null );

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
    dateObserved = moment.tz(
      observation.time_observed_at,
      observation.observed_time_zone
    );
  } else if ( observation.observed_on ) {
    dateObserved = moment( observation.observed_on );
  }
  const onDate = dateObserved ? dateObserved.format( "YYYY-MM-DD" ) : null;
  const calendarDate = dateObserved ? dateObserved.format( "YYYY/M/D" ) : null;
  const { testingApiV2 } = config || {};
  const loadObservationCallback = ( e, o ) => {
    if ( e.metaKey || e.ctrlKey ) return;
    e.preventDefault( );
    showNewObservation( o, { useInstance: !testingApiV2 } );
  };
  const userLogin = observation.user.login;
  // obs list starts with the previous 8 obs
  let observations = _.take( otherObservations.earlierUserObservations, 8 );
  // reverse them since they are ordered DESC, and we want to show them ASC
  observations.reverse( );
  // add the next 7 obs
  observations = observations.concat( _.take( otherObservations.laterUserObservations, 7 ) );
  if ( observations.length < 15 ) {
    // if we don't have 15 yet, add the rest of the next obs
    observations = observations.concat( otherObservations.laterUserObservations.slice( 7 ) );
    observations = _.take( observations, 15 );
  }
  if ( observations.length < 15 ) {
    // if we don't have 15 yet, add as many more previous obs as we need
    const moreEarlier = _.take(
      otherObservations.earlierUserObservations.slice( 8 ), 15 - observations.length
    );
    moreEarlier.reverse( );
    observations = moreEarlier.concat( observations );
  }

  const items = observations.map( ( o, i ) => {
    const taxon = o.taxon
      ? {
        ...o.taxon,
        default_photo: o.photo( ) ? {
          medium_url: o.photo( "medium" ),
          square_url: o.photo( "square" ) || o.photo( "medium" )
        } : undefined
      }
      : { id: o.id, name: I18n.t( "unknown" ), iconic_taxon_name: "unknown" };
    return (
      <TaxonThumbnail
        key={`more-obs-${o.uuid}`}
        ref={i === 0 ? firstItemRef : null}
        taxon={taxon}
        urlForTaxon={( ) => `/observations/${o.id}`}
        onClick={e => loadObservationCallback( e, o )}
        config={config}
        width={160}
      />
    );
  } );

  return (
    <div className="MoreFromUser">
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
      <Carousel
        items={items}
        itemRef={firstItemRef}
      />
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

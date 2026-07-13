import _ from "lodash";
import moment from "moment-timezone";
import React, { useMemo } from "react";
import Carousel from "../../../shared/components/carousel";
import TaxonThumbnail from "../../../shared/components/taxon_thumbnail";
import type {
  Config, Observation
} from "../../../shared/types";

// inaturalistjs Observation instances carry a uuid and the observation-date
// fields this component reads; none of these are on the shared Observation type.
type UserObservation = Observation & { uuid?: string };
type ShowObservation = UserObservation & {
  time_observed_at?: string;
  observed_time_zone?: string;
  observed_on?: string;
};

export interface MoreFromUserProps {
  observation?: ShowObservation;
  otherObservations: {
    earlierUserObservations: UserObservation[];
    laterUserObservations: UserObservation[];
  };
  showNewObservation: ( o: UserObservation, options: { useInstance: boolean } ) => void;
  config?: Config & { testingApiV2?: boolean };
}

const MoreFromUser = ( {
  observation,
  otherObservations,
  showNewObservation,
  config = {}
}: MoreFromUserProps ) => {
  const observations = useMemo( ( ) => {
    // obs list starts with the previous 3 obs
    let obs = _.take( otherObservations.earlierUserObservations, 3 );
    // reverse them since they are ordered DESC, and we want to show them ASC
    obs.reverse( );
    // add the next 3 obs
    obs = obs.concat( _.take( otherObservations.laterUserObservations, 3 ) );
    if ( obs.length < 6 ) {
      // if we don't have 6 yet, add the rest of the next obs
      obs = obs.concat( otherObservations.laterUserObservations.slice( 3 ) );
      obs = _.take( obs, 6 );
    }
    if ( obs.length < 6 ) {
      // if we don't have 6 yet, add as many more previous obs as we need
      const moreEarlier = _.take(
        otherObservations.earlierUserObservations.slice( 3 ),
        6 - obs.length
      );
      moreEarlier.reverse( );
      obs = moreEarlier.concat( obs );
    }
    return obs;
  }, [otherObservations] );
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
  let dateObserved: moment.Moment | undefined;
  if ( observation.time_observed_at ) {
    dateObserved = moment.tz(
      observation.time_observed_at,
      observation.observed_time_zone as string
    );
  } else if ( observation.observed_on ) {
    dateObserved = moment( observation.observed_on );
  }
  const onDate = dateObserved ? dateObserved.format( "YYYY-MM-DD" ) : null;
  const calendarDate = dateObserved ? dateObserved.format( "YYYY/M/D" ) : null;
  const { testingApiV2 } = config;
  const loadObservationCallback = ( e: React.MouseEvent, o: UserObservation ) => {
    if ( e.metaKey || e.ctrlKey ) return;
    e.preventDefault( );
    showNewObservation( o, { useInstance: !testingApiV2 } );
  };
  const userLogin = observation.user.login;
  const carouselItems = observations.map( o => (
    <TaxonThumbnail
      key={`more-obs-${o.uuid}`}
      taxon={o.taxon || { id: o.id, name: I18n.t( "unknown" ), iconic_taxon_name: "unknown" }}
      // null (not undefined) so a photoless observation shows an iconic
      // placeholder rather than borrowing the taxon's default photo.
      photo={o.photos?.[0] ?? null}
      urlForTaxon={( ) => `/observations/${o.id}`}
      onClick={e => loadObservationCallback( e, o )}
      config={config}
      width={160}
    />
  ) );
  return (
    <div className="MoreFromUser">
      <h3>
        <span
          dangerouslySetInnerHTML={{
            __html: I18n.t( "more_from_x", { x: `<a href="/people/${userLogin}">${userLogin}</a>` } )
          }}
        />
        <div className="links">
          <span className="view">{ I18n.t( "label_colon", { label: I18n.t( "view" ) } ) }</span>
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
      <Carousel items={carouselItems} />
    </div>
  );
};

export default MoreFromUser;

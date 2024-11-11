import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";

const PreviousNextButtons = ( {
  otherObservations,
  showNewObservation,
  config,
  observation
} ) => {
  if ( (
    observation
    && observation.obscured
    && !observation.private_geojson
  ) || _.isEmpty( observation ) ) {
    return <div />;
  }
  const previousDisabled = _.isEmpty( otherObservations.earlierUserObservations );
  const nextDisabled = _.isEmpty( otherObservations.laterUserObservations );
  const { testingApiV2 } = config || {};
  let prevAction = e => {
    e.preventDefault( );
    return false;
  };
  let nextAction = e => {
    e.preventDefault( );
    return false;
  };
  let prevAlt = I18n.t( "unknown" );
  let nextAlt = I18n.t( "unknown" );
  const userPrefersSciname = config && config.currentUser
    && config.currentUser.prefers_scientific_name_first;
  let previousObs;
  if ( !previousDisabled ) {
    previousObs = otherObservations.earlierUserObservations[0];
    prevAction = e => {
      e.preventDefault( );
      showNewObservation( previousObs, { useInstance: !testingApiV2 } );
      return false;
    };
    if ( previousObs.taxon ) {
      prevAlt = previousObs.taxon.name;
      if ( previousObs.taxon.preferred_common_name && !userPrefersSciname ) {
        prevAlt = iNatModels.Taxon.titleCaseName( previousObs.taxon.preferred_common_name );
      }
    } else if ( previousObs.species_guess ) {
      prevAlt = previousObs.species_guess;
    }
  }
  let nextObs;
  if ( !nextDisabled ) {
    nextObs = otherObservations.laterUserObservations[0];
    nextAction = e => {
      e.preventDefault( );
      showNewObservation( nextObs, { useInstance: !testingApiV2 } );
      return false;
    };
    if ( nextObs.taxon ) {
      nextAlt = nextObs.taxon.name;
      if ( nextObs.taxon.preferred_common_name && !userPrefersSciname ) {
        nextAlt = iNatModels.Taxon.titleCaseName( nextObs.taxon.preferred_common_name );
      }
    } else if ( nextObs.species_guess ) {
      nextAlt = nextObs.species_guess;
    }
  }
  const isRTL = $( "html[dir='rtl']" ).length > 0;
  return (
    <div className="PreviousNextButtons">
      <a
        href={
          previousObs
            ? `/observations/${previousObs.id || previousObs.uuid}`
            : `/observations/${observation.user.login}`
        }
        className={`previous ${previousDisabled ? "disabled" : ""}`}
        onClick={prevAction}
        alt={I18n.t( "previous_observation" )}
        title={prevAlt}
      >
        <i className={`fa fa-chevron-${isRTL ? "right" : "left"}`} />
      </a>
      <a
        href={
          nextObs
            ? `/observations/${nextObs.id || nextObs.uuid}`
            : `/observations/${observation.user.login}`
        }
        className={`next ${nextDisabled ? "disabled" : ""}`}
        onClick={nextAction}
        alt={I18n.t( "next_observation" )}
        title={nextAlt}
      >
        <i className={`fa fa-chevron-${isRTL ? "left" : "right"}`} />
      </a>
    </div>
  );
};

PreviousNextButtons.propTypes = {
  otherObservations: PropTypes.object,
  showNewObservation: PropTypes.func,
  config: PropTypes.object,
  observation: PropTypes.object
};

export default PreviousNextButtons;

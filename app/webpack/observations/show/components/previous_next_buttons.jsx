import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";

const PreviousNextButtons = ( { otherObservations, showNewObservation, config } ) => {
  const previousDisabled = _.isEmpty( otherObservations.earlierUserObservations );
  const nextDisabled = _.isEmpty( otherObservations.laterUserObservations );
  let prevAction = ( ) => { };
  let nextAction = ( ) => { };
  let prevAlt = I18n.t( "unknown" );
  let nextAlt = I18n.t( "unknown" );
  const userPrefersSciname = config && config.currentUser &&
    config.currentUser.prefers_scientific_name_first;
  if ( !previousDisabled ) {
    const previousObs = otherObservations.earlierUserObservations[0];
    prevAction = ( ) => { showNewObservation( previousObs, { useInstance: true } ); };
    if ( previousObs.taxon ) {
      prevAlt = previousObs.taxon.name;
      if ( previousObs.taxon.preferred_common_name && !userPrefersSciname ) {
        prevAlt = iNatModels.Taxon.titleCaseName( previousObs.taxon.preferred_common_name );
      }
    } else if ( previousObs.species_guess ) {
      prevAlt = previousObs.species_guess;
    }
  }
  if ( !nextDisabled ) {
    const nextObs = otherObservations.laterUserObservations[0];
    nextAction = ( ) => { showNewObservation( nextObs, { useInstance: true } ); };
    if ( nextObs.taxon ) {
      nextAlt = nextObs.taxon.name;
      if ( nextObs.taxon.preferred_common_name && !userPrefersSciname ) {
        nextAlt = iNatModels.Taxon.titleCaseName( nextObs.taxon.preferred_common_name );
      }
    } else if ( nextObs.species_guess ) {
      nextAlt = nextObs.species_guess;
    }
  }
  return (
    <div className="PreviousNextButtons">
      <div
        className={ `previous ${previousDisabled ? "disabled" : ""}` }
        onClick={ prevAction }
        alt={ prevAlt }
        title={ prevAlt }
      >
        <i className="fa fa-chevron-left" />
      </div>
      <div
        className={ `next ${nextDisabled ? "disabled" : ""}` }
        onClick={ nextAction }
        alt={ nextAlt }
        title={ nextAlt }
      >
        <i className="fa fa-chevron-right" />
      </div>
    </div>
  );
};

PreviousNextButtons.propTypes = {
  otherObservations: PropTypes.object,
  showNewObservation: PropTypes.func,
  config: PropTypes.object
};

export default PreviousNextButtons;

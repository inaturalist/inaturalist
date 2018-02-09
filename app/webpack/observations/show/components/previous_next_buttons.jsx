import _ from "lodash";
import React, { PropTypes } from "react";

const PreviousNextButtons = ( { otherObservations, showNewObservation, config } ) => {
  const previousDisabled = _.isEmpty( otherObservations.earlierUserObservations );
  const nextDisabled = _.isEmpty( otherObservations.laterUserObservations );
  let prevAction = ( ) => { };
  let nextAction = ( ) => { };
  let prevAlt;
  let nextAlt;
  if ( !previousDisabled ) {
    const previousObs = otherObservations.earlierUserObservations[0];
    prevAction = ( ) => { showNewObservation( previousObs, { useInstance: true } ); };
    if ( previousObs.taxon ) {
      if ( config && config.currentUser && config.currentUser.prefers_scientific_name_first ) {
        prevAlt = previousObs.taxon.name;
      } else {
        prevAlt = previousObs.taxon.preferred_common_name || previousObs.taxon.name;
      }
    } else {
      prevAlt = I18n.t( "unknown" );
    }
  }
  if ( !nextDisabled ) {
    const nextObs = otherObservations.laterUserObservations[0];
    nextAction = ( ) => { showNewObservation( nextObs, { useInstance: true } ); };
    if ( nextObs.taxon ) {
      if ( config && config.currentUser && config.currentUser.prefers_scientific_name_first ) {
        nextAlt = nextObs.taxon.name;
      } else {
        nextAlt = nextObs.taxon.preferred_common_name || nextObs.taxon.name;
      }
    } else {
      nextAlt = I18n.t( "unknown" );
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

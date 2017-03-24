import _ from "lodash";
import React, { PropTypes } from "react";
import ObservationFieldValue from "./observation_field_value";

const ObservationFields = ( { observation } ) => {
  if ( !observation || _.isEmpty( observation.ofvs ) ) { return ( <span /> ); }
  // fieldIDs used by projects
  const projectFieldIDs = _.compact( _.flatten( observation.project_observations.map( po => (
    ( po.project.project_observation_fields || [] ).map( pof => (
      pof.observation_field.id ) ) ) ) ) );
  let nonProjectFieldValues = observation.ofvs;
  if ( projectFieldIDs.length > 0 ) {
    // remove any project fields from this presentation
    nonProjectFieldValues = _.filter( observation.ofvs, ofv => ( (
      !_.includes( projectFieldIDs, ofv.field_id )
    ) ) );
  }
  if ( _.isEmpty( nonProjectFieldValues ) ) { return ( <span /> ); }
  const sortedFieldValues = _.sortBy( nonProjectFieldValues, ofv => (
    `${ofv.value ? "a" : "z"}:${ofv.name}:${ofv.value}`
  ) );
  return (
    <div className="ObservationFields">
      <h4>Observation Fields</h4>
      { sortedFieldValues.map( ofv => (
        <ObservationFieldValue ofv={ ofv } key={ `field-value-${ofv.uuid}`} />
      ) ) }
    </div>
  );
};

ObservationFields.propTypes = {
  observation: PropTypes.object
};

export default ObservationFields;

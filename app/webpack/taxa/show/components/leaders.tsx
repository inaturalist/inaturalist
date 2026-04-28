import React from "react";
import TopObserverContainer from "../containers/top_observer_container";
import TopIdentifierContainer from "../containers/top_identifier_container";
import NumSpeciesContainer from "../containers/num_species_container";
import LastObservationContainer from "../containers/last_observation_container";
import NumObservationsContainer from "../containers/num_observations_container";

interface Taxon {
  rank_level?: number;
  complete_species_count?: number;
}

interface LeadersProps {
  taxon: Taxon;
}

const Leaders = ( { taxon }: LeadersProps ) => {
  const optional = ( taxon.rank_level ?? 0 ) > 10 && taxon.complete_species_count
    ? <NumSpeciesContainer />
    : <LastObservationContainer />;
  return (
    <div className="Leaders">
      <div className="LeadersGrid">
        <TopObserverContainer />
        <TopIdentifierContainer />
        { optional }
        <NumObservationsContainer />
      </div>
    </div>
  );
};

export default Leaders;

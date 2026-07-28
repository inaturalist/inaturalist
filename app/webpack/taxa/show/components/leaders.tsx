import React from "react";
import TopObserverContainer from "../containers/top_observer_container";
import TopIdentifierContainer from "../containers/top_identifier_container";
import NumSpeciesContainer from "../containers/num_species_container";
import LastObservationContainer from "../containers/last_observation_container";
import NumObservationsContainer from "../containers/num_observations_container";
import type { Taxon } from "../../../shared/types";
import taxaShowResponsive from "../responsive";
import LeadersLegacy from "./leaders_legacy";

interface LeadersProps {
  taxon: Taxon;
}

const LeadersResponsive = ( { taxon }: LeadersProps ) => {
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

// Renders the pre-WEB-984 layout unless the user is testing responsiveness.
// The legacy module is untyped JS, so its props are asserted to match.
type GateProps = React.ComponentProps<typeof LeadersResponsive>;
const LegacyFallback = LeadersLegacy as unknown as React.ComponentType<GateProps>;

/* eslint-disable react/jsx-props-no-spreading */
const Leaders = ( props: GateProps ) => (
  taxaShowResponsive( )
    ? <LeadersResponsive {...props} />
    : <LegacyFallback {...props} />
);
/* eslint-enable react/jsx-props-no-spreading */

export default Leaders;

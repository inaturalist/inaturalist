import React from "react";
import PropTypes from "prop-types";
import SplitTaxon from "../../../shared/components/split_taxon";
import APIWrapper from "../../../shared/containers/inat_api_duck_container";
import Observations from "./observations";
import Species from "./species";

const ObservationsGridContainer = APIWrapper( "observations", Observations );
const SpeciesGridContainer = APIWrapper( "species", Species );

const DetailsView = ( {
  lifelist
} ) => {
  const leafCount = lifelist.detailsTaxon
    ? lifelist.detailsTaxon.descendantCount : lifelist.leavesCount;
  const observationCount = lifelist.detailsTaxon
    ? lifelist.detailsTaxon.descendant_obs_count : lifelist.observationsCount;
  return (
    <div className="Details">
      <h3>
        { lifelist.detailsTaxon
          ? ( <SplitTaxon taxon={lifelist.detailsTaxon} noInactive /> )
          : "All Observations" }
      </h3>
      <div className="stats">
        <span className="stat">
          <span className="attr">Observations:</span>
          <span className="value">{ observationCount.toLocaleString( ) }</span>
        </span>
        <span className="stat">
          <span className="attr">Leaf Taxa:</span>
          <span className="value">{ leafCount.toLocaleString( ) }</span>
        </span>
      </div>
      { lifelist.detailsView === "observations"
        ? ( <ObservationsGridContainer /> )
        : ( <SpeciesGridContainer lifelist={lifelist} /> )
      }
    </div>
  );
};

DetailsView.propTypes = {
  lifelist: PropTypes.object
};

export default DetailsView;

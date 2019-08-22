import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import Observation from "../../../projects/show/components/observation";
import SplitTaxon from "../../../shared/components/split_taxon";

const DetailsView = ( {
  config, taxon, observations, totalObservations, totalLeaves
} ) => {
  const loader = ( <div key="observations-flex-grid-view-loading" className="loading_spinner huge" /> );
  const leafCount = taxon ? taxon.descendantCount : totalLeaves;
  const observationCount = taxon ? taxon.count : totalObservations;
  return (
    <div className="Details">
      <h3>
        { taxon
          ? ( <SplitTaxon taxon={taxon} noInactive /> )
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
      {
        _.isEmpty( observations ) ? loader : (
          <div className="ObservationsGrid" key="observations-flex-grid">
            { observations.map( o => {
              const itemDim = 200;
              let width = itemDim;
              const dims = o.photos.length > 0 && o.photos[0].dimensions( );
              if ( dims ) {
                width = itemDim / dims.height * dims.width;
              } else {
                width = itemDim;
              }
              return (
                <Observation
                  key={`obs-${o.id}`}
                  observation={o}
                  width={width}
                  height={itemDim}
                  config={config}
                />
              );
            } )
          }
        </div>
      )
    }
    </div>
  );
};

DetailsView.propTypes = {
  config: PropTypes.object,
  totalObservations: PropTypes.number,
  totalLeaves: PropTypes.number,
  taxon: PropTypes.object,
  observations: PropTypes.array
};

export default DetailsView;

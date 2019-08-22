import React from "react";
import PropTypes from "prop-types";
import TaxaTreeContainer from "../containers/taxa_tree_container";
import DetailsView from "./details_view";

const App = ( { config, lifelist, togglePhotos } ) => (
  <div id="App" className="container">
    <div className="menu">
      <button
        type="button"
        className="btn btn-default btn-sm"
        onClick={togglePhotos}
      >
        Show Photos
      </button>
    </div>
    <div className="FlexGrid">
      <div className="FlexCol tree-col">
        <TaxaTreeContainer key={`tree-${lifelist.updatedAt}`} />
      </div>
      <div className="FlexCol details-col">
        <DetailsView
          config={config}
          totalObservations={lifelist.observationsCount}
          totalLeaves={lifelist.leavesCount}
          taxon={lifelist.detailsTaxon}
          observations={lifelist.detailsTaxonObservations}
        />
      </div>
    </div>
  </div>
);

App.propTypes = {
  config: PropTypes.object,
  lifelist: PropTypes.object,
  togglePhotos: PropTypes.func
};

export default App;

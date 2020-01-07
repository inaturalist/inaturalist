import React from "react";
import ReactDOMServer from "react-dom/server";
import PropTypes from "prop-types";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxaSunburst from "./taxa_sunburst";
import NewSpecies from "./new_species";

const Taxa = ( {
  site,
  user,
  data,
  rootTaxonID,
  currentUser,
  year
} ) => {
  let newSpecies;
  if ( data && data.accumulation ) {
    newSpecies = (
      <NewSpecies
        accumulation={data.accumulation}
        user={user}
        currentUser={currentUser}
        year={year}
        site={site}
      />
    );
  }
  let newSpeciesObservations;
  return (
    <div className="Taxa">
      { user && data && data.tree_taxa && rootTaxonID && (
        <TaxaSunburst
          data={data.tree_taxa}
          rootTaxonID={rootTaxonID}
          labelForDatum={d => (
            ReactDOMServer.renderToString(
              <div>
                <SplitTaxon taxon={d.data} noInactive user={currentUser} />
                <div className="text-muted small">
                  { I18n.t( "x_observations", { count: I18n.toNumber( d.value, { precision: 0 } ) } ) }
                </div>
              </div>
            )
          )}
        />
      ) }
      { newSpecies }
      { newSpeciesObservations }
    </div>
  );
};

Taxa.propTypes = {
  data: PropTypes.object,
  site: PropTypes.object,
  user: PropTypes.object,
  currentUser: PropTypes.object,
  rootTaxonID: PropTypes.number,
  year: PropTypes.number
};

Taxa.defaultProps = {
  year: ( new Date( ) ).getFullYear( )
};

export default Taxa;

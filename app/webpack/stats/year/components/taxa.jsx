import React from "react";
import ReactDOMServer from "react-dom/server";
import PropTypes from "prop-types";
import _ from "lodash";
import moment from "moment";
import SplitTaxon from "../../../shared/components/split_taxon";
import DateHistogram from "./date_histogram";
import TaxaSunburst from "./taxa_sunburst";

const Taxa = ( {
  user,
  data,
  rootTaxonID,
  currentUser
} ) => {
  let accumulation;
  if ( data && data.accumulation_by_created ) {
    const series = {};
    const grayColor = "rgba( 40%, 40%, 40%, 0.5 )";
    series.accumulated = {
      title: I18n.t( "total" ),
      data: _.map( data.accumulation_by_created, i => ( { date: i.date, value: i.accumulated_taxa_count } ) ),
      style: "line",
      color: grayColor,
      label: d => `<strong>${moment( d.date ).format( "MMMM" )}</strong>: ${d.value}`
    };
    series.novel = {
      title: I18n.t( "new" ),
      data: _.map( data.accumulation_by_created, i => ( { date: i.date, value: i.novel_taxon_ids.length } ) ),
      style: "line",
      label: d => `<strong>${moment( d.date ).format( "MMMM" )}</strong>: ${d.value}`
    };
    accumulation = (
      <div>
        <h1>{ I18n.t( "new_species_this_year" ) }</h1>
        <DateHistogram
          series={series}
          tickFormatBottom={d => moment( d ).format( "MMM YY" )}
        />
      </div>
    );
  }
  return (
    <div className="Taxa">
      { user && data && data.tree_taxa && rootTaxonID && (
        <TaxaSunburst
          data={data.tree_taxa}
          rootTaxonID={rootTaxonID}
          labelForDatum={d => (
            ReactDOMServer.renderToString(
              <div>
                <SplitTaxon taxon={d.data} noInactive forceRank user={currentUser} />
                <div className="text-muted small">
                  { I18n.t( "x_observations", { count: I18n.toNumber( d.value, { precision: 0 } ) } ) }
                </div>
              </div>
            )
          )}
        />
      ) }
      { accumulation }
    </div>
  );
};

Taxa.propTypes = {
  data: PropTypes.object,
  user: PropTypes.object,
  currentUser: PropTypes.object,
  rootTaxonID: PropTypes.number
};

export default Taxa;

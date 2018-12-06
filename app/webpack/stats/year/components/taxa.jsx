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
  currentUser,
  year
} ) => {
  let accumulation;
  if ( data && data.accumulation ) {
    const series = {};
    const grayColor = "rgba( 40%, 40%, 40%, 0.5 )";
    series.accumulated = {
      title: I18n.t( "running_total" ),
      data: _.map( data.accumulation, i => ( {
        date: i.date,
        value: i.accumulated_taxa_count
      } ) ),
      style: "bar",
      color: grayColor,
      label: d => `<strong>${moment( d.date ).add( 1, "month" ).format( "MMMM" )}</strong>: ${d.value}`
    };
    series.novel = {
      title: I18n.t( "newly_observed" ),
      data: _.map( data.accumulation, i => ( {
        date: i.date,
        value: i.novel_taxon_ids.length,
        novel_taxon_ids: i.novel_taxon_ids,
        offset: i.accumulated_taxa_count - i.novel_taxon_ids.length
      } ) ),
      style: "bar",
      label: d => `<strong>${moment( d.date ).add( 1, "month" ).format( "MMMM" )}</strong>: ${d.value}`
    };
    accumulation = (
      <div>
        <h1>{ I18n.t( "new_species_this_year" ) }</h1>
        <DateHistogram
          series={series}
          tickFormatBottom={d => moment( d ).format( "MMM 'YY" )}
          legendPosition="nw"
          onClick={d => {
            if ( d.seriesName === "accumulated" ) {
              return false;
            }

            let url = `/observations?place_id=any&verifiable=true&view=species&taxon_ids=${d.novel_taxon_ids.join( "," )}`;
            url += `&year=${d.date.getFullYear( )}&month=${d.date.getMonth() + 2}`;
            if ( user ) {
              url += `&user_id=${user.login}`;
            }
            window.open( url, "_blank" );
            return false;
          }}
          // xExtent={[moment( `${year}-02-01` ), moment( `${year + 1}-01-01` )]}
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
  rootTaxonID: PropTypes.number,
  year: PropTypes.number
};

Taxa.defaultProps = {
  year: ( new Date( ) ).getFullYear( )
};

export default Taxa;

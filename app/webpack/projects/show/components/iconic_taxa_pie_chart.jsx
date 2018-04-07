import _ from "lodash";
import React, { PropTypes } from "react";
import PieChartForIconicTaxonCounts from
  "../../../stats/year/components/pie_chart_for_iconic_taxon_counts";

const IconicTaxaPieChart = ( { project } ) => {
  if ( !project.iconic_taxa_species_counts_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  if ( _.isEmpty( project.iconic_taxa_species_counts.results ) ) { return ( <div /> ); }
  const data = _.fromPairs(
    _.map( project.iconic_taxa_species_counts.results, r => [r.taxon.name, r.count] ) );
  const total = project.species_loaded ?
    I18n.toNumber( project.species.total_results, { precision: 0 } ) : "--";
  return (
    <div className="IconicTaxaPieChart">
      <div className="count-label">
        { I18n.t( "x_species", { count: total } ) }
      </div>
      <PieChartForIconicTaxonCounts
        data={ data }
        margin={ { top: 0, bottom: 120, left: 0, right: 0 } }
        donutWidth={ 20 }
        urlPrefix={ `/observations?project_id=${project.id}` }
        labelForDatum={ d => {
          const degrees = ( d.endAngle - d.startAngle ) * 180 / Math.PI;
          const percent = _.round( degrees / 360 * 100, 2 );
          const value = I18n.t( "x_species", {
            count: I18n.toNumber( d.value, { precision: 0 } )
          } );
          return `<strong>${d.data.fullLabel}</strong>: ${value} (${percent}%)`;
        }}
      />
    </div>
  );
};

IconicTaxaPieChart.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  leaders: PropTypes.array,
  type: PropTypes.string
};

export default IconicTaxaPieChart;

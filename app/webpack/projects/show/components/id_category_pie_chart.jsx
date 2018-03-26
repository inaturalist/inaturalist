import _ from "lodash";
import React, { PropTypes } from "react";
import { COLORS } from "../../../shared/util";
import PieChart from "../../../stats/year/components/pie_chart";

const IdCategroryPieChart = ( { project } ) => {
  if ( !project.identification_categories_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  if ( _.isEmpty( project.identification_categories.results ) ) { return ( <div /> ); }
  const data = _.fromPairs(
    _.map( project.identification_categories.results, r => [r.category, r.count] ) );
  // const total = project.identifiers_loaded ?
  //   I18n.toNumber( project.species.total_results, { precision: 0 } ) : "--";
  return (
    <div className="IconicTaxaPieChart">
      <div className="count-label">
        { I18n.t( "x_identifications", { count: "---" } ) }
      </div>
      <PieChart
        data={[
          {
            label: _.capitalize( I18n.t( "improving" ) ),
            value: data.improving,
            color: COLORS.inatGreen,
            category: "improving"
          },
          {
            label: _.capitalize( I18n.t( "supporting" ) ),
            value: data.supporting,
            color: COLORS.inatGreenLight,
            category: "supporting"
          },
          {
            label: _.capitalize( I18n.t( "leading" ) ),
            value: data.leading,
            color: COLORS.needsIdYellow,
            category: "leading"
          },
          {
            label: _.capitalize( I18n.t( "maverick" ) ),
            value: data.maverick,
            color: COLORS.failRed,
            category: "maverick"
          }
        ]}
        legendColumns={ 1 }
        legendColumnWidth={ 120 }
        // labelForDatum={ d => {
        //   const degrees = ( d.endAngle - d.startAngle ) * 180 / Math.PI;
        //   const percent = _.round( degrees / 360 * 100, 2 );
        //   const value = I18n.t( "x_observations", {
        //     count: I18n.toNumber( d.value, { precision: 0 } )
        //   } );
        //   return `<strong>${d.data.fullLabel}</strong>: ${value} (${percent}%)`;
        // }}
        margin={ { top: 0, bottom: 120, left: 0, right: 0 } }
        donutWidth={ 20 }
        onClick={ d => {
          const url = `/identifications?project_id=${project.id}&for=others&current=true&category=${d.data.category}`;
          window.open( url, "_blank" );
        } }
      />
    </div>
  );
};

IdCategroryPieChart.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  leaders: PropTypes.array,
  type: PropTypes.string
};

export default IdCategroryPieChart;

import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { COLORS } from "../../../shared/util";
import PieChart from "../../../stats/year/components/pie_chart";

const IdCategroryPieChart = ( { project } ) => {
  if ( !project.identification_categories_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  if ( _.isEmpty( project.identification_categories.results ) ) { return ( <div /> ); }
  const data = _.fromPairs(
    _.map( project.identification_categories.results, r => [r.category, r.count] ) );
  const total = _.sum( _.map( project.identification_categories.results, "count" ) );
  return (
    <div className="IconicTaxaPieChart">
      <div className="count-label">
        { I18n.t( "x_identifications_", { count: I18n.toNumber( total, { precision: 0 } ) } ) }
      </div>
      <PieChart
        data={[
          {
            label: I18n.t( "improving" ),
            value: data.improving,
            color: COLORS.inatGreen,
            category: "improving"
          },
          {
            label: I18n.t( "supporting" ),
            value: data.supporting,
            color: COLORS.inatGreenLight,
            category: "supporting"
          },
          {
            label: I18n.t( "leading" ),
            value: data.leading,
            color: COLORS.needsIdYellow,
            category: "leading"
          },
          {
            label: I18n.t( "maverick" ),
            value: data.maverick,
            color: COLORS.failRed,
            category: "maverick"
          }
        ]}
        legendColumns={ 1 }
        legendColumnWidth={ 120 }
        margin={ { top: 0, bottom: 130, left: 0, right: 0 } }
        donutWidth={ 20 }
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

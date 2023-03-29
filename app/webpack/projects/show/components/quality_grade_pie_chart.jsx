import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { COLORS } from "../../../shared/util";
import PieChart from "../../../stats/year/components/pie_chart";

const QualityGradePieChart = ( { project } ) => {
  if ( !project.quality_grade_counts_loaded ) {
    return ( <div className="loading_spinner huge" /> );
  }
  if ( _.isEmpty( project.quality_grade_counts.results ) ) { return ( <div /> ); }
  const data = _.fromPairs(
    _.map( project.quality_grade_counts.results, r => [r.quality_grade, r.count] ) );
  const total = project.recent_observations_loaded ?
    I18n.toNumber( project.recent_observations.total_results, { precision: 0 } ) : "--";
  return (
    <div className="QualityGradePieChart">
      <div className="count-label">
        { I18n.t( "x_observations_", { count: total } ) }
      </div>
      <PieChart
        data={[
          {
            label: I18n.t( "research_grade" ),
            fullLabel: I18n.t( "research_grade" ),
            value: data.research,
            color: COLORS.inatGreenLight,
            enLabel: "research"
          },
          {
            label: I18n.t( "needs_id_" ),
            fullLabel: I18n.t( "needs_id_" ),
            value: data.needs_id,
            color: COLORS.needsIdYellow,
            enLabel: "needs_id"
          },
          {
            label: I18n.t( "casual_" ),
            fullLabel: I18n.t( "casual_" ),
            value: data.casual,
            color: "#aaaaaa",
            enLabel: "casual"
          }
        ]}
        legendColumns={ 1 }
        legendColumnWidth={ 120 }
        labelForDatum={ d => {
          const degrees = ( d.endAngle - d.startAngle ) * 180 / Math.PI;
          const percent = _.round( degrees / 360 * 100, 2 );
          const value = I18n.t( "x_observations", {
            count: I18n.toNumber( d.value, { precision: 0 } )
          } );
          return `<strong>${d.data.fullLabel}</strong>: ${value} (${percent}%)`;
        }}
        margin={ { top: 0, bottom: 130, left: 0, right: 0 } }
        donutWidth={ 20 }
        onClick={( _clickEvent, d ) => {
          const url = `/observations?project_id=${project.id}&quality_grade=${d.data.enLabel}&verifiable=any`;
          window.open( url, "_blank" );
        }}
      />
    </div>
  );
};

QualityGradePieChart.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  margin: PropTypes.object,
  labelForDatum: PropTypes.func,
  innerRadius: PropTypes.number,
  donutWidth: PropTypes.number,
  urlPrefix: PropTypes.string
};

export default QualityGradePieChart;

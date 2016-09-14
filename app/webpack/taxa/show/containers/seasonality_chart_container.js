import { connect } from "react-redux";
import _ from "lodash";
import C3Chart from "../../../observations/identify/components/c3chart";

function mapStateToProps( state ) {
  const keys = _.keys(
    state.observations.monthOfYearFrequency.verifiable
  ).map( k => parseInt( k, 0 ) ).sort( ( a, b ) => a - b );
  const verifiableFrequency = state.observations.monthOfYearFrequency.verifiable || {};
  const researchFrequency = state.observations.monthOfYearFrequency.research || {};
  const config = {
    data: {
      columns: [
        ["verifiable", ...keys.map( i => verifiableFrequency[i.toString( )] || 0 )],
        ["research", ...keys.map( i => researchFrequency[i.toString( )] || 0 )]
      ],
      colors: {
        verifiable: "#aaaaaa",
        research: "#74ac00"
      }
    },
    axis: {
      x: {
        type: "category",
        categories: keys.map( i => I18n.t( "date.abbr_month_names" )[i].toUpperCase( ) )
      },
      y: {
        show: false,
        padding: {
          bottom: 0
        }
      }
    },
    legend: {
      show: false
    },
    point: {
      show: false
    },
    tooltip: {
      format: {
        title: i => `${I18n.t( "date.month_names" )[i + 1].toUpperCase( )} ${I18n.t( "observations" ).toUpperCase( )}`,
        name: name => I18n.t( name )
      }
    }
  };
  return { config, className: "SeasonalityChart FrequencyChart" };
}

function mapDispatchToProps( ) {
  return {};
}

const SeasonalityChartContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( C3Chart );

export default SeasonalityChartContainer;

import { connect } from "react-redux";
import _ from "lodash";
import moment from "moment";
import C3Chart from "../../../observations/identify/components/c3chart";

function mapStateToProps( state ) {
  const verifiableFrequency = state.observations.monthFrequency.verifiable || {};
  const researchFrequency = state.observations.monthFrequency.research || {};
  const dates = _.keys( state.observations.monthFrequency.verifiable ).sort( );
  const years = _.uniq( dates.map( d => new Date( d ).getFullYear( ) ) ).sort( );
  const chunks = _.chunk( years, 2 );
  const regions = chunks.map( pair => (
    {
      start: `${pair[0]}-01-01`,
      end: `${pair[0] + 1}-01-01`
    }
  ) );
  return {
    config: {
      data: {
        x: "x",
        columns: [
          ["x", ...dates],
          ["verifiable", ...dates.map( d => verifiableFrequency[d] || 0 )],
          ["research", ...dates.map( d => researchFrequency[d] || 0 )]
        ],
        colors: {
          verifiable: "#aaaaaa",
          research: "#74ac00"
        }
      },
      axis: {
        x: {
          type: "timeseries",
          tick: {
            culling: true,
            values: years.map( y => `${y}-06-15` ),
            format: "%Y"
          },
          extent: [moment( ).subtract( 10, "years" ).toDate( ), new Date( )]
        },
        y: {
          show: false,
          padding: {
            bottom: 0
          }
        }
      },
      zoom: {
        enabled: true,
        rescale: true
      },
      legend: {
        show: false
      },
      point: {
        show: false
      },
      tooltip: {
        format: {
          title: d => `${I18n.t( "date.abbr_month_names" )[d.getMonth( ) + 1].toUpperCase( )} ${d.getFullYear( )} ${I18n.t( "observations" ).toUpperCase( )}`,
          name: name => I18n.t( name )
        }
      },
      regions
    },
    className: "HistoryChart FrequencyChart"
  };
}

function mapDispatchToProps( ) {
  return {};
}

const HistoryChartContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( C3Chart );

export default HistoryChartContainer;

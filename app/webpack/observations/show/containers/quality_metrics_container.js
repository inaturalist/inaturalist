import _ from "lodash";
import { connect } from "react-redux";
import QualityMetrics from "../components/quality_metrics";
import { voteMetric, unvoteMetric } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config,
    qualityMetrics: _.groupBy( state.qualityMetrics, "metric" )
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    voteMetric: ( metric, params ) => { dispatch( voteMetric( metric, params ) ); },
    unvoteMetric: ( metric ) => { dispatch( unvoteMetric( metric ) ); }
  };
}

const QualityMetricsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( QualityMetrics );

export default QualityMetricsContainer;

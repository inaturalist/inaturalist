import { connect } from "react-redux";
import _ from "lodash";
import QualityMetrics from "../../show/components/quality_metrics";
import { voteMetric, unvoteMetric } from "../actions/current_observation_actions";
import { setFlaggingModalState } from "../../show/ducks/flagging_modal";

function mapStateToProps( state ) {
  return {
    observation: state.currentObservation.observation,
    config: state.config,
    qualityMetrics: Object.assign( { },
      _.groupBy( state.qualityMetrics, "metric" ),
      _.groupBy( state.currentObservation.observation.votes, "vote_scope" ) ),
    tableOnly: true
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setFlaggingModalState: newState => dispatch( setFlaggingModalState( newState ) ),
    voteMetric: ( metric, params ) => dispatch( voteMetric( metric, params ) ),
    unvoteMetric: metric => dispatch( unvoteMetric( metric ) )
  };
}

const QualityMetricsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( QualityMetrics );

export default QualityMetricsContainer;

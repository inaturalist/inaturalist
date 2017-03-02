import _ from "lodash";
import { connect } from "react-redux";
import QualityMetrics from "../components/quality_metrics";
import { voteMetric, unvoteMetric } from "../ducks/observation";
import { setState } from "../ducks/flagging_modal";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config,
    qualityMetrics: Object.assign( { },
      _.groupBy( state.qualityMetrics, "metric" ),
      _.groupBy( state.observation.votes, "vote_scope" )
    )
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setFlaggingModalState: ( key, value ) => { dispatch( setState( key, value ) ); },
    voteMetric: ( metric, params ) => { dispatch( voteMetric( metric, params ) ); },
    unvoteMetric: ( metric ) => { dispatch( unvoteMetric( metric ) ); }
  };
}

const QualityMetricsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( QualityMetrics );

export default QualityMetricsContainer;

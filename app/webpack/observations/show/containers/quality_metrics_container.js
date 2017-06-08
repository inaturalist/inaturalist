import _ from "lodash";
import { connect } from "react-redux";
import QualityMetrics from "../components/quality_metrics";
import { voteMetric, unvoteMetric } from "../ducks/observation";
import { setFlaggingModalState } from "../ducks/flagging_modal";
import { updateSession } from "../ducks/users";

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
    setFlaggingModalState: ( newState ) => { dispatch( setFlaggingModalState( newState ) ); },
    voteMetric: ( metric, params ) => { dispatch( voteMetric( metric, params ) ); },
    unvoteMetric: ( metric ) => { dispatch( unvoteMetric( metric ) ); },
    updateSession: params => { dispatch( updateSession( params ) ); }
  };
}

const QualityMetricsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( QualityMetrics );

export default QualityMetricsContainer;

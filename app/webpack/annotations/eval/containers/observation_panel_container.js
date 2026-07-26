import { connect } from "react-redux";
import ObservationPanel from "../components/observation_panel";
import { setSpecies, revertSpecies, resetState } from "../ducks/annotation_eval";

const mapStateToProps = state => ( {
  obsCard: state.annotationEval.obsCard,
  species: state.annotationEval.species,
  speciesSource: state.annotationEval.speciesSource,
  visionSpecies: state.annotationEval.visionSpecies,
  status: state.annotationEval.status
} );

const mapDispatchToProps = dispatch => ( {
  setSpecies: taxon => dispatch( setSpecies( taxon ) ),
  revertSpecies: ( ) => dispatch( revertSpecies( ) ),
  resetState: ( ) => dispatch( resetState( ) )
} );

export default connect( mapStateToProps, mapDispatchToProps )( ObservationPanel );

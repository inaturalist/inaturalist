import { connect } from "react-redux";

import RelationshipsCheckbox from "../components/relationships_checkbox";
import { handleCheckboxChange } from "../ducks/relationships";

function mapStateToProps( state ) {
  // clone array to get props to propagate
  return {
    relationships: [...state.relationships.relationships]
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    handleCheckboxChange: ( e, id ) => { dispatch( handleCheckboxChange( e, id ) ); }
  };
}

const RelationshipsCheckboxContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( RelationshipsCheckbox );

export default RelationshipsCheckboxContainer;

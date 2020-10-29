import { connect } from "react-redux";

import Relationships from "../components/relationships";

function mapStateToProps( ) {
  return {};
}

function mapDispatchToProps( ) {
  return {};
}

const RelationshipsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Relationships );

export default RelationshipsContainer;

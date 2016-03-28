import React from "react";
import ReactDOM from "react-dom";

class TaxonMap extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( domNode ).taxonMap( this.props );
  }
  render( ) {
    return (
      <div className="taxon-map" style={ { minHeight: "10px" } } />
    );
  }
}

export default TaxonMap;

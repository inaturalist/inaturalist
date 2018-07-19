import _ from "lodash";
import { Component } from "react";
import PropTypes from "prop-types";

class SelectionBasedComponent extends Component {

  constructor( props, context ) {
    super( props, context );
    this.valuesOf = this.valuesOf.bind( this );
    this.commonValue = this.commonValue.bind( this );
  }

  valuesOf( attr, obsCards ) {
    return _.uniqBy(
      _.map( obsCards || this.props.selectedObsCards, c => {
        const val = c[attr];
        return !val ? null : val;
      } ),
      a => a && ( a.id || a ) );
  }

  uniqueValuesOf( attr, obsCards ) {
    return _.uniq( _.compact( _.flatten( this.valuesOf( attr, obsCards ) ) ) );
  }

  commonValue( attr, obsCards ) {
    const uniq = this.valuesOf( attr, obsCards );
    return ( uniq.length === 1 ) ? uniq[0] : "";
  }

}

SelectionBasedComponent.propTypes = {
  selectedObsCards: PropTypes.object,
  reactKey: PropTypes.string
};

export default SelectionBasedComponent;

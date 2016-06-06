import _ from "lodash";
import { PropTypes, Component } from "react";

class SelectionBasedComponent extends Component {

  constructor( props, context ) {
    super( props, context );
    this.valuesOf = this.valuesOf.bind( this );
    this.commonValue = this.commonValue.bind( this );
  }

  valuesOf( attr ) {
    return _.uniqBy(
      _.map( this.props.selectedObsCards, c => {
        const val = c[attr];
        return !val ? null : val;
      } ),
      a => a && ( a.id || a ) );
  }

  commonValue( attr ) {
    const uniq = this.valuesOf( attr );
    return ( uniq.length === 1 ) ? uniq[0] : undefined;
  }
}

SelectionBasedComponent.propTypes = {
  selectedObsCards: PropTypes.object,
  reactKey: PropTypes.string
};

export default SelectionBasedComponent;

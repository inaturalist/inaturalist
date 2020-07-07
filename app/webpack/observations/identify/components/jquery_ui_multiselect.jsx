import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import _ from "lodash";

class JQueryUIMultiselect extends React.Component {
  componentDidMount( ) {
    const { onOpen, onChange } = this.props;
    const domNode = ReactDOM.findDOMNode( this );
    const opts = {
      checkAllText: I18n.t( "all" ),
      uncheckAllText: I18n.t( "none" )
    };
    if ( typeof ( onOpen ) === "function" ) {
      opts.open = onOpen;
    }
    if ( typeof ( onChange ) === "function" ) {
      $( domNode ).change( ( ) => onChange( $( domNode ).val( ) ) );
    }
    $( domNode ).multiselect( opts );
  }

  render( ) {
    const {
      className,
      defaultValue,
      data,
      id
    } = this.props;
    return (
      <select
        className={className}
        id="filters-dates-month"
        multiple
        defaultValue={defaultValue}
      >
        { _.map( data, ( opt, i ) => (
          <option
            value={opt.value}
            key={`${id}-${i}`}
          >
            { opt.label }
          </option>
        ) ) }
      </select>
    );
  }
}

JQueryUIMultiselect.propTypes = {
  className: PropTypes.string,
  onChange: PropTypes.func,
  onOpen: PropTypes.func,
  id: PropTypes.string,
  data: PropTypes.array,
  defaultValue: PropTypes.array
};

export default JQueryUIMultiselect;

import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import _ from "lodash";

class JQueryUIMultiselect extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const opts = {
      checkAllText: I18n.t( "all" ),
      uncheckAllText: I18n.t( "none" )
    };
    if ( typeof( this.props.onOpen ) === "function" ) {
      opts.open = this.props.onOpen;
    }
    if ( typeof( this.props.onChange ) === "function" ) {
      $( domNode ).change( ( ) => this.props.onChange( $( domNode ).val( ) ) );
    }
    $( domNode ).multiselect( opts );
  }

  render( ) {
    return (
      <select
        className={this.props.className}
        id="filters-dates-month"
        multiple
        defaultValue={this.props.defaultValue}
      >
        { _.map( this.props.data, ( opt, i ) => (
          <option
            value={opt.value}
            key={`${this.props.id}-${i}`}
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
  onClick: PropTypes.func,
  onOpen: PropTypes.func,
  id: PropTypes.string,
  data: PropTypes.array,
  defaultValue: PropTypes.array
};

export default JQueryUIMultiselect;

import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import inaturalistjs from "inaturalistjs";

class UserAutocomplete extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const opts = Object.assign( {}, this.props, {
      idEl: $( "input[name='user_id']", domNode )
    } );
    $( "input[name='user_login']", domNode ).userAutocomplete( opts );
    this.fetchUser( );
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.initialUserID &&
         this.props.initialUserID !== prevProps.initialUserID ) {
      this.fetchUser( );
    }
  }

  fetchUser( ) {
    if ( this.props.initialUserID ) {
      inaturalistjs.users.fetch( this.props.initialUserID ).then( r => {
        if ( r.results.length > 0 ) {
          this.updateUser( { user: r.results[0] } );
        }
      } );
    }
  }

  updateUser( options = { } ) {
    const domNode = ReactDOM.findDOMNode( this );
    if ( options.user ) {
      $( "input[name='user_login']", domNode ).
        trigger( "assignSelection", Object.assign(
          {},
          options.user,
          { title: options.user.login }
        ) );
    }
  }

  inputElement( ) {
    const domNode = ReactDOM.findDOMNode( this );
    return $( "input[name='user_login']", domNode );
  }

  render( ) {
    return (
      <span className="UserAutocomplete form-group">
        <input
          type="search"
          name="user_login"
          className={`form-control ${this.props.className}`}
          placeholder={ this.props.placeholder || I18n.t( "username_or_user_id" ) }
        />
        <input type="hidden" name="user_id" />
      </span>
    );
  }
}


UserAutocomplete.propTypes = {
  resetOnChange: PropTypes.bool,
  bootstrapClear: PropTypes.bool,
  afterSelect: PropTypes.func,
  afterUnselect: PropTypes.func,
  initialSelection: PropTypes.object,
  initialUserID: React.PropTypes.oneOfType( [
    React.PropTypes.string,
    React.PropTypes.number
  ] ),
  className: PropTypes.string,
  placeholder: PropTypes.string
};

export default UserAutocomplete;

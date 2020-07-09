import React from "react";
import PropTypes from "prop-types";
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
    const { initialUserID } = this.props;
    if ( initialUserID && initialUserID !== prevProps.initialUserID ) {
      this.fetchUser( );
    }
  }

  fetchUser( ) {
    const { initialUserID } = this.props;
    if ( initialUserID ) {
      inaturalistjs.users.fetch( initialUserID ).then( r => {
        if ( r.results.length > 0 ) {
          this.updateUser( { user: r.results[0] } );
        }
      } );
    }
  }

  updateUser( options = { } ) {
    const domNode = ReactDOM.findDOMNode( this );
    if ( options.user ) {
      $( "input[name='user_login']", domNode )
        .trigger( "assignSelection", Object.assign(
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
    const { className, placeholder } = this.props;
    return (
      <span className="UserAutocomplete form-group">
        <input
          type="search"
          name="user_login"
          className={`form-control ${className}`}
          placeholder={placeholder || I18n.t( "username_or_user_id" )}
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
  initialUserID: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.number
  ] ),
  className: PropTypes.string,
  placeholder: PropTypes.string,
  projectID: PropTypes.number
};

export default UserAutocomplete;

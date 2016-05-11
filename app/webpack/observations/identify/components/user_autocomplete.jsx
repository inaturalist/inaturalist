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
    if ( this.props.initialuserID &&
         this.props.initialuserID !== prevProps.initialuserID ) {
      this.fetchUser( );
    }
  }

  fetchUser( ) {
    if ( this.props.initialuserID ) {
      inaturalistjs.users.fetch( this.props.initialuserID ).then( r => {
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
          { title: options.user.title }
        ) );
    }
  }

  render( ) {
    return (
      <span className="UserAutocomplete form-group">
        <input
          type="search"
          name="user_login"
          className={`form-control ${this.props.className}`}
          placeholder={ I18n.t( "username_or_user_id" ) }
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
  initialuserID: PropTypes.number,
  className: PropTypes.string
};

export default UserAutocomplete;

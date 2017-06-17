import _ from "lodash";
import React, { PropTypes } from "react";
import { Glyphicon, Panel } from "react-bootstrap";

class Tags extends React.Component {
  constructor( props ) {
    super( props );
    this.submitTag = this.submitTag.bind( this );
    this.removeTag = this.removeTag.bind( this );
    const currentUser = props.config && props.config.currentUser;
    this.state = {
      open: currentUser ? !currentUser.prefers_hide_obs_show_tags : true
    };
  }

  submitTag( e ) {
    e.preventDefault( );
    const input = $( e.target ).find( "input" );
    this.props.addTag( _.trim( input.val( ) ) );
    input.val( "" );
  }

  removeTag( tag ) {
    this.props.removeTag( tag );
  }

  render( ) {
    const observation = this.props.observation;
    const config = this.props.config;
    const loggedIn = config && config.currentUser;
    const viewerIsObserver = loggedIn && config.currentUser.id === observation.user.id;
    if ( !observation || ( _.isEmpty( observation.tags ) && !viewerIsObserver ) ) {
      return ( <span /> );
    }
    let addTagInput;
    if ( viewerIsObserver ) {
      addTagInput = (
        <form onSubmit={ this.submitTag }>
          <div className="form-group">
            <input type="text" placeholder={ I18n.t( "add_tag" ) } className="form-control" />
          </div>
        </form>
      );
    }
    const count = observation.tags.length > 0 ? `(${observation.tags.length})` : "";
    return (
      <div className="Tags">
        <h4
          className="collapsable"
          onClick={ ( ) => {
            if ( loggedIn ) {
              this.props.updateSession( { prefers_hide_obs_show_tags: this.state.open } );
            }
            this.setState( { open: !this.state.open } );
          } }
        >
          <i className={ `fa fa-chevron-circle-${this.state.open ? "down" : "right"}` } />
          { I18n.t( "tags" ) } { count }
        </h4>
        <Panel collapsible expanded={ this.state.open }>
          { addTagInput }
          {
            _.sortBy( observation.tags, t => ( _.lowerCase( t.tag || t ) ) ).map( t => {
              let remove;
              const tag = t.tag || t;
              if ( viewerIsObserver ) {
                remove = t.api_status ? ( <div className="loading_spinner" /> ) : (
                  <Glyphicon glyph="remove-circle" onClick={ () => { this.removeTag( tag ); } } />
                );
              }
              return (
                <div className={ `tag ${t.api_status ? "loading" : ""}` } key={ tag }>
                  <a href={ `/observations?q=${t}&search_on=tags` }>
                    { tag }
                  </a>
                  { remove }
                </div>
              );
            } )
          }
        </Panel>
      </div>
    );
  }
}

Tags.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  addTag: PropTypes.func,
  removeTag: PropTypes.func,
  updateSession: PropTypes.func
};

export default Tags;

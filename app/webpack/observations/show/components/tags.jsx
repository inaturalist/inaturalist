import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
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
    const { addTag } = this.props;
    addTag( _.trim( input.val( ) ) );
    input.val( "" );
  }

  removeTag( tag ) {
    const { removeTag } = this.props;
    removeTag( tag );
  }

  render( ) {
    const {
      config,
      observation,
      updateSession
    } = this.props;
    const { open } = this.state;
    const loggedIn = config && config.currentUser;
    if ( !observation || !observation.user ) { return ( <div /> ); }
    const tags = observation.tags || [];
    const viewerIsObserver = loggedIn && config.currentUser.id === observation.user.id;
    if ( _.isEmpty( observation.tags ) && !viewerIsObserver ) { return ( <div /> ); }
    let addTagInput;
    if ( viewerIsObserver ) {
      addTagInput = (
        <form onSubmit={this.submitTag}>
          <div className="form-group">
            <input type="text" placeholder={I18n.t( "add_tag" )} className="form-control" />
          </div>
        </form>
      );
    }
    const count = tags.length > 0 ? `(${tags.length})` : "";
    return (
      <div className="Tags collapsible-section">
        <h4
          className="collapsible"
          onClick={( ) => {
            if ( loggedIn ) {
              updateSession( { prefers_hide_obs_show_tags: open } );
            }
            this.setState( { open: !open } );
          }}
        >
          <i className={`fa fa-chevron-circle-${open ? "down" : "right"}`} />
          { I18n.t( "tags" ) }
          { " " }
          { count }
        </h4>
        <Panel expanded={open} onToggle={() => {}}>
          <Panel.Collapse>
            { addTagInput }
            {
              _.sortBy( tags, t => ( _.lowerCase( t.tag || t ) ) ).map( t => {
                let remove;
                const tag = t.tag || t;
                if ( viewerIsObserver ) {
                  remove = t.api_status ? ( <div className="loading_spinner" /> ) : (
                    <Glyphicon glyph="remove-circle" onClick={() => { this.removeTag( tag ); }} />
                  );
                }
                return (
                  <div className={`tag ${t.api_status ? "loading" : ""}`} key={tag}>
                    <a href={`/observations?q=${t}&search_on=tags`}>
                      { tag }
                    </a>
                    { remove }
                  </div>
                );
              } )
            }
          </Panel.Collapse>
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

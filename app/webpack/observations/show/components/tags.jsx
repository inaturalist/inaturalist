import _ from "lodash";
import React, { PropTypes } from "react";
import { Glyphicon, Panel } from "react-bootstrap";

class Tags extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      open: false
    };
    this.submitTag = this.submitTag.bind( this );
    this.removeTag = this.removeTag.bind( this );
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
    const viewerIsObserver = config && config.currentUser &&
      config.currentUser.id === observation.user.id;
    if ( !observation || ( _.isEmpty( observation.tags ) && !viewerIsObserver ) ) {
      return ( <span /> );
    }
    let addTagLink;
    let addTagInput;
    if ( viewerIsObserver ) {
      addTagLink = (
        <span
          className="add"
          onClick={ ( ) => this.setState( { open: !this.state.open } ) }
        >{ I18n.t( "add_tag" ) }</span>
      );
      addTagInput = (
        <Panel collapsible expanded={ this.state.open }>
          <form onSubmit={ this.submitTag }>
            <div className="form-group">
              <input type="text" placeholder={ I18n.t( "add_tag" ) } className="form-control" />
            </div>
          </form>
        </Panel>
      );
    }
    return (
      <div className="Tags">
        <h4>{ I18n.t( "tags" ) } ({ observation.tags.length }) { addTagLink }</h4>
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
      </div>
    );
  }
}

Tags.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  addTag: PropTypes.func,
  removeTag: PropTypes.func
};

export default Tags;

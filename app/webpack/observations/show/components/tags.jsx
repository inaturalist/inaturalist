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
    const tag = _.trim( input.val( ) );
    if ( tag ) {
      let newTagList = tag;
      if ( !_.isEmpty( this.props.observation.tags ) ) {
        newTagList = `${newTagList}, ${this.props.observation.tags.join( ", " )}`;
      }
      this.props.updateObservation( { tag_list: newTagList } );
    }
    // TODO: disable new entries until we've set a temprary tag list
    // or the update is finished. We don't want to wipe out tags with
    // very fast entries
    input.val( "" );
  }

  removeTag( tag ) {
    if ( tag ) {
      const newTagList = _.without( this.props.observation.tags, tag ).join( ", " );
      this.props.updateObservation( { tag_list: newTagList } );
    }
  }

  render( ) {
    const observation = this.props.observation;
    const config = this.props.config;
    if ( !observation ) { return ( <div /> ); }
    const viewerIsObserver = config && config.currentUser &&
      config.currentUser.id === observation.user.id;
    let addTagLink;
    let addTagInput;
    if ( viewerIsObserver ) {
      addTagLink = (
        <span
          className="add"
          onClick={ ( ) => this.setState( { open: !this.state.open } ) }
        >Add Tag</span>
      );
      addTagInput = (
        <Panel collapsible expanded={ this.state.open }>
          <form onSubmit={ this.submitTag }>
            <div className="form-group">
              <input type="text" placeholder="Add tag" className="form-control" />
            </div>
          </form>
        </Panel>
      );
    }
    return (
      <div className="Tags">
        <h4>Tags ({ observation.tags.length }) { addTagLink }</h4>
        { addTagInput }
        {
          observation.tags.map( t => {
            let remove;
            if ( viewerIsObserver ) {
              remove = (
                <Glyphicon glyph="remove-circle" onClick={ () => { this.removeTag( t ); } } />
              );
            }
            return (
              <div className="tag" key={ t }>
                { t }
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
  updateObservation: PropTypes.func
};

export default Tags;

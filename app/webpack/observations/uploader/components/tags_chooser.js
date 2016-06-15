import _ from "lodash";
import React, { PropTypes } from "react";
import { Glyphicon, Badge, OverlayTrigger, Tooltip } from "react-bootstrap";
import SelectionBasedComponent from "./selection_based_component";

class TagsChooser extends SelectionBasedComponent {

  constructor( props, context ) {
    super( props, context );
    this.removeTag = this.removeTag.bind( this );
    this.submitTag = this.submitTag.bind( this );
  }

  submitTag( e ) {
    e.preventDefault( );
    const input = $( e.target ).find( "input" );
    const tag = _.trim( input.val( ) );
    if ( tag ) {
      this.props.appendToSelectedObsCards( { tags:
        _.map( tag.split( "," ), t => _.trim( t ) ) } );
    }
    input.val( "" );
  }

  removeTag( t ) {
    this.props.removeFromSelectedObsCards( { tags: t } );
  }

  render( ) {
    const commonTags = this.uniqueValuesOf( "tags" );
    return (
      <div className="tags">
        <form onSubmit={this.submitTag}>
          <OverlayTrigger
            placement="top"
            delayShow={ 1000 }
            overlay={ ( <Tooltip id="tag-tip">Tags are keywords you can add to an observation to make them easier to find. For example, if a barracuda followed you on a scuba diving trip in Turks and Caicos, you might tag the observation "scary, barracuda, scuba diving, vacation, turks and caicos"</Tooltip> ) }
          >
            <div className="input-group">
              <input
                type="text"
                className="form-control"
                placeholder="Add tags..."
              />
              <span className="input-group-btn">
                <button
                  className="btn btn-default"
                  type="submit"
                >
                  Add
                </button>
              </span>
            </div>
          </OverlayTrigger>
        </form>
        <div className="taglist">
          { _.map( commonTags, ( t, i ) => (
            <OverlayTrigger
              placement="top"
              delayShow={ 1000 }
              key={ `tt-tag${i}` }
              overlay={ ( <Tooltip id={ `tt-tag${i}` }>{ t }</Tooltip> ) }
            >
              <Badge className="tag" key={ t }>
                <span className="wrap">{ t }</span>
                <Glyphicon glyph="remove-circle" onClick={ () => {
                  this.removeTag( t );
                } }
                />
              </Badge>
            </OverlayTrigger>
          ) ) }
        </div>
      </div>
    );
  }
}

TagsChooser.propTypes = {
  appendToSelectedObsCards: PropTypes.func,
  removeFromSelectedObsCards: PropTypes.func
};

export default TagsChooser;

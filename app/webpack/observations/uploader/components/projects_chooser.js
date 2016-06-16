import _ from "lodash";
import React, { PropTypes } from "react";
import { Glyphicon, Badge, OverlayTrigger, Tooltip } from "react-bootstrap";
import SelectionBasedComponent from "./selection_based_component";

class ProjectsChooser extends SelectionBasedComponent {

  constructor( props, context ) {
    super( props, context );
    this.removeProject = this.removeProject.bind( this );
    this.setUpProjectAutocomplete = this.setUpProjectAutocomplete.bind( this );
  }

  componentDidMount( ) {
    this.setUpProjectAutocomplete( );
  }

  componentDidUpdate( ) {
    this.setUpProjectAutocomplete( );
  }

  setUpProjectAutocomplete( ) {
    const input = $( ".projects input" );
    if ( input.data( "uiAutocomplete" ) ) {
      input.autocomplete( "destroy" );
      input.removeData( "uiAutocomplete" );
    }
    input.projectAutocomplete( {
      resetOnChange: false,
      allowEnterSubmit: true,
      idEl: $( "<input/>" ),
      appendTo: $( ".leftColumn" ),
      onResults: items => {
        if ( items !== null && items.length === 0 ) {
          $( ".projects input" ).addClass( "failed" );
        } else {
          $( ".projects input" ).removeClass( "failed" );
        }
      },
      afterSelect: p => {
        if ( p ) {
          this.props.appendToSelectedObsCards( { projects: p.item } );
        }
        input.val( "" );
      }
    } );
  }

  removeProject( p ) {
    this.props.removeFromSelectedObsCards( { projects: p } );
  }

  chooseFirstProject( e ) {
    e.preventDefault( );
    const input = $( ".panel-group .projects input" );
    if ( input.data( "uiAutocomplete" ) ) {
      input.trigger( "selectFirst" );
    }
  }

  render( ) {
    const commonProjects = this.uniqueValuesOf( "projects" );
    return (
      <div className="projects">
        <form onSubmit={this.chooseFirstProject}>
          <OverlayTrigger
            placement="top"
            delayShow={ 1000 }
            overlay={ ( <Tooltip id="project-tip">Projects are collections of observations by numerous people gathered for a common purpose</Tooltip> ) }
          >
            <div className="input-group">
              <div className="input-group-addon input-sm">
                <Glyphicon glyph="briefcase" />
              </div>
              <input
                type="text"
                className="form-control"
                placeholder={ "Add to a project..." }
              />
            </div>
          </OverlayTrigger>
        </form>
        <div className="taglist">
          { _.map( commonProjects, ( p, i ) => {
            const key = p.title;
            return (
              <OverlayTrigger
                placement="top"
                delayShow={ 1000 }
                key={ `tt-proj${i}` }
                overlay={ ( <Tooltip id={ `tt-proj${i}` }>{ key }</Tooltip> ) }
              >
                <Badge className="tag" key={ key }>
                  <span className="wrap">{ key }</span>
                  <Glyphicon glyph="remove-circle" onClick={ () => {
                    this.removeProject( p );
                  } }
                  />
                </Badge>
              </OverlayTrigger>
            );
          } ) }
        </div>
      </div>
    );
  }

}

ProjectsChooser.propTypes = {
  appendToSelectedObsCards: PropTypes.func,
  removeFromSelectedObsCards: PropTypes.func
};

export default ProjectsChooser;

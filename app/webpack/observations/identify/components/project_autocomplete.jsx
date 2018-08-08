import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import inaturalistjs from "inaturalistjs";

class ProjectAutocomplete extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const opts = Object.assign( {}, this.props, {
      idEl: $( "input[name='project_id']", domNode )
    } );
    $( "input[name='project_title']", domNode ).projectAutocomplete( opts );
    this.fetchProject( );
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.initialProjectID &&
         this.props.initialProjectID !== prevProps.initialProjectID ) {
      this.fetchProject( );
    }
  }

  fetchProject( ) {
    if ( this.props.initialProjectID ) {
      inaturalistjs.projects.fetch( this.props.initialProjectID ).then( r => {
        if ( r.results.length > 0 ) {
          this.updateProject( { project: r.results[0] } );
        }
      } );
    }
  }

  updateProject( options = { } ) {
    const domNode = ReactDOM.findDOMNode( this );
    if ( options.project ) {
      $( "input[name='project_title']", domNode ).
        trigger( "assignSelection", Object.assign(
          {},
          options.project,
          { title: options.project.title }
        ) );
    }
  }

  inputElement( ) {
    const domNode = ReactDOM.findDOMNode( this );
    return $( "input[name='project_title']", domNode );
  }

  render( ) {
    return (
      <span className="ProjectAutocomplete">
        <input
          type="search"
          name="project_title"
          className={`form-control ${this.props.className}`}
          placeholder={ I18n.t( "name_or_slug" ) }
        />
        <input type="hidden" name="project_id" />
      </span>
    );
  }
}


ProjectAutocomplete.propTypes = {
  resetOnChange: PropTypes.bool,
  bootstrapClear: PropTypes.bool,
  afterSelect: PropTypes.func,
  afterUnselect: PropTypes.func,
  initialSelection: PropTypes.object,
  initialProjectID: PropTypes.number,
  className: PropTypes.string
};

export default ProjectAutocomplete;

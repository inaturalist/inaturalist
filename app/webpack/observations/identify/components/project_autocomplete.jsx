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
    // Update the jQuery UI autocomplete with the new options
    const domNode = ReactDOM.findDOMNode( this );
    $( "input[name='project_title']", domNode ).autocomplete( "option", this.props );

    // Fetch the new project if necessary
    const { initialProjectID } = this.props;
    if ( initialProjectID
         && initialProjectID !== prevProps.initialProjectID ) {
      this.fetchProject( );
    }
  }

  fetchProject( ) {
    const { initialProjectID } = this.props;
    if ( initialProjectID ) {
      inaturalistjs.projects.fetch( initialProjectID ).then( r => {
        if ( r.results.length > 0 ) {
          this.updateProject( { project: r.results[0] } );
        }
      } );
    }
  }

  updateProject( options = { } ) {
    const domNode = ReactDOM.findDOMNode( this );
    if ( options.project ) {
      $( "input[name='project_title']", domNode )
        .trigger( "assignSelection", Object.assign(
          {},
          options.project,
          { title: options.project.title }
        ) );
    }
  }

  // This does get used as a public instance method
  // eslint-disable-next-line react/no-unused-class-component-methods
  inputElement( ) {
    const domNode = ReactDOM.findDOMNode( this );
    return $( "input[name='project_title']", domNode );
  }

  render( ) {
    const { className, disabled, placeholder } = this.props;
    return (
      <span className="ProjectAutocomplete">
        <input
          type="search"
          name="project_title"
          className={`form-control ${className}`}
          placeholder={placeholder || I18n.t( "name_or_slug" )}
          disabled={disabled}
        />
        <input type="hidden" name="project_id" />
      </span>
    );
  }
}

ProjectAutocomplete.propTypes = {
  disabled: PropTypes.bool,
  initialProjectID: PropTypes.oneOfType( [
    PropTypes.number,
    PropTypes.string
  ] ),
  className: PropTypes.string,
  placeholder: PropTypes.string
};

export default ProjectAutocomplete;

import React from "react";
import PropTypes from "prop-types";

import ProjectAutocomplete from "../../../observations/identify/components/project_autocomplete";
import FavoriteProject from "./favorite_project";

const FavoriteProjects = ( { addProject, favoriteProjects, updateFavedProjectIds } ) => {
  const [positions, setPositions] = React.useState( favoriteProjects.map( p => p.id ) );

  // update temp state when favoriteProjects actually updates
  React.useEffect( ( ) => {
    if ( JSON.stringify( positions ) !== JSON.stringify( favoriteProjects.map( p => p.id ) ) ) {
      setPositions( favoriteProjects.map( p => p.id ) );
    }
  }, [
    JSON.stringify( favoriteProjects.map( p => p.id ) )
  ] );

  const projectAutocompleteRef = React.useRef( );

  return (
    <div className="FavoriteProjects">
      <h5>{ I18n.t( "your_favorite_projects" ) }</h5>
      <p className="text-muted">
        { I18n.t( "your_favorite_projects_desc" ) }
      </p>
      { positions.map( ( projectId, position ) => {
        const project = favoriteProjects.find( p => p.id === projectId );
        if ( !project ) return null;
        return (
          <FavoriteProject
            key={`fave-project-${project.id}`}
            position={position}
            onDrag={( oldPosition, newPosition ) => {
              const changedProjectId = positions[oldPosition];
              const newPositions = [...positions];
              newPositions.splice( oldPosition, 1 );
              newPositions.splice( newPosition, 0, changedProjectId );
              setPositions( newPositions );
            }}
            project={project}
            onChange={() => updateFavedProjectIds( positions )}
            onRemove={removedProject => {
              const newPositions = positions.filter( pid => pid !== removedProject.id );
              setPositions( newPositions );
              updateFavedProjectIds( newPositions );
            }}
          />
        );
      } ) }
      <div className="add-project">
        <ProjectAutocomplete
          afterSelect={result => {
            addProject( result.item );
            projectAutocompleteRef.current?.inputElement( )?.val( "" );
            projectAutocompleteRef.current?.inputElement( )?.trigger( "resetSelection" );
          }}
          placeholder={I18n.t( "add_a_project" )}
          ref={projectAutocompleteRef}
        />
      </div>
    </div>
  );
};

FavoriteProjects.propTypes = {
  addProject: PropTypes.func,
  favoriteProjects: PropTypes.arrayOf( PropTypes.shape( {
    id: PropTypes.number,
    title: PropTypes.string
  } ) ),
  updateFavedProjectIds: PropTypes.func
};

export default FavoriteProjects;

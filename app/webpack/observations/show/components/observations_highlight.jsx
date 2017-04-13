import _ from "lodash";
import React, { PropTypes } from "react";

const ObservationsHighlight = ( { title, observations, searchParams, showNewObservation } ) => {
  if ( _.isEmpty( observations ) ) { return ( <div /> ); }
  const loadObservationCallback = ( e, observation ) => {
    if ( !e.metaKey ) {
      e.preventDefault( );
      showNewObservation( observation );
    }
  };
  return (
    <div className="ObservationsHighlight">
      <h3>
        { title }
        <a href={ `/observations?${$.param( searchParams )}` }>
          { I18n.t( "view_all" ) }
        </a>
      </h3>
      <div className="list">
        { _.filter( observations, o => ( o.photo( ) ) ).map( o => (
          <div className="photo" key={ `highlight-${o.id}` }>
            <a
              href={ `/observations/${o.id}` }
              style={ { backgroundImage: `url( '${o.photo( "small" )}' )` } }
              onClick={ e => { loadObservationCallback( e, o ); } }
            />
          </div>
          ) )
        }
      </div>
    </div>
  );
};

ObservationsHighlight.propTypes = {
  title: PropTypes.string,
  searchParams: PropTypes.object,
  observations: PropTypes.array,
  showNewObservation: PropTypes.func
};

export default ObservationsHighlight;

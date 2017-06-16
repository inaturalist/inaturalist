import _ from "lodash";
import React, { PropTypes } from "react";
import { Col } from "react-bootstrap";

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
      <Col xs={ 12 }>
        <h3>
          { title }
          <a href={ `/observations?${$.param( searchParams )}` }>
            { I18n.t( "view_all" ) }
          </a>
        </h3>
      </Col>
      <div className="list">
        { _.filter( observations, o => ( o.photo( ) ) ).map( o => (
          <Col xs={ 2 } key={ `highlight-${o.id}` }>
            <div className="photo">
              <a
                href={ `/observations/${o.id}` }
                style={ { backgroundImage: `url( '${o.photo( "small" )}' )` } }
                onClick={ e => { loadObservationCallback( e, o ); } }
              />
            </div>
          </Col>
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

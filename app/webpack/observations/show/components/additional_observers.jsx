import React from "react";
import PropTypes from "prop-types";
import UserWithIcon from "./user_with_icon";
import UserAutocomplete from "../../identify/components/user_autocomplete";

// Creator-only widget for managing the additional observers on an observation.
// Presentational: all data + behavior arrive as props so it can be tested
// without a store (see additional_observers.test.jsx).
const AdditionalObservers = ( {
  config,
  observation,
  viewerIsObserver,
  addAdditionalObserver,
  removeAdditionalObserver
} ) => {
  if ( !viewerIsObserver ) { return null; }

  const observers = observation.additional_observers || [];

  return (
    <div className="AdditionalObservers" id="AdditionalObservers">
      <h4>{ I18n.t( "additional_observers" ) }</h4>
      <div className="observer-list">
        { observers.map( additionalObserver => {
          const user = additionalObserver.user || additionalObserver;
          return (
            <div className="observer-row" key={`additional-observer-${user.id}`}>
              <UserWithIcon config={config} user={user} skipSubtitleLink />
              <button
                type="button"
                className="btn btn-nostyle remove-observer"
                title={I18n.t( "remove" )}
                onClick={( ) => removeAdditionalObserver( user.id )}
              >
                <i className="fa fa-times-circle-o" />
              </button>
            </div>
          );
        } ) }
      </div>
      <UserAutocomplete
        afterSelect={e => {
          const item = e.item || {};
          addAdditionalObserver( { ...item, id: item.user_id || item.id } );
        }}
        bootstrapClear
        config={config}
        placeholder={I18n.t( "add_observers" )}
      />
    </div>
  );
};

AdditionalObservers.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  viewerIsObserver: PropTypes.bool,
  addAdditionalObserver: PropTypes.func,
  removeAdditionalObserver: PropTypes.func
};

AdditionalObservers.defaultProps = {
  config: {},
  observation: {}
};

export default AdditionalObservers;

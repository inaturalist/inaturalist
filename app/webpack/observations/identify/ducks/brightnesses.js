import _ from "lodash";

const SET_BRIGHTNESSES = "set_brightnesses";

export default function reducer( state = { }, action ) {
  if ( action.type === SET_BRIGHTNESSES ) {
    return Object.assign( {}, state, action.brightnesses );
  }
  return state;
}

function setBrightnesses( brightnesses ) {
  return { type: SET_BRIGHTNESSES, brightnesses };
}

function setBrightnessKey( currentObs ) {
  const observation = currentObs && currentObs.observation;
  const imagesCurrentIndex = currentObs && currentObs.imagesCurrentIndex;
  return `${observation.id}-${imagesCurrentIndex}`;
}

function setNewBrightnesses( currentBrightnesses, brightnessKey, newBrightness ) {
  return Object.assign( {}, currentBrightnesses, { [brightnessKey]: newBrightness } );
}

function increaseBrightness( ) {
  return ( dispatch, getState ) => {
    const { currentObservation, brightnesses: currentBrightnesses } = getState( );
    const brightnessKey = setBrightnessKey( currentObservation );
    const existing = currentBrightnesses[brightnessKey] || 1;
    let newBrightness = _.round( existing + 0.2, 2 );
    if ( newBrightness > 3 ) {
      newBrightness = 3;
    }
    const newBrightnesses = setNewBrightnesses( currentBrightnesses, brightnessKey, newBrightness );
    dispatch( setBrightnesses( newBrightnesses ) );
  };
}

function decreaseBrightness( ) {
  return ( dispatch, getState ) => {
    const { currentObservation, brightnesses: currentBrightnesses } = getState( );
    const brightnessKey = setBrightnessKey( currentObservation );
    const existing = currentBrightnesses[brightnessKey] || 1;
    let newBrightness = _.round( existing - 0.2, 2 );
    if ( newBrightness < 0.2 ) {
      newBrightness = 0.2;
    }
    const newBrightnesses = setNewBrightnesses( currentBrightnesses, brightnessKey, newBrightness );
    dispatch( setBrightnesses( newBrightnesses ) );
  };
}

function resetBrightness( ) {
  return ( dispatch, getState ) => {
    const { currentObservation, brightnesses: currentBrightnesses } = getState( );
    const brightnessKey = setBrightnessKey( currentObservation );
    const newBrightnesses = setNewBrightnesses( currentBrightnesses, brightnessKey, 1 );
    dispatch( setBrightnesses( newBrightnesses ) );
  };
}

export {
  SET_BRIGHTNESSES,
  increaseBrightness,
  decreaseBrightness,
  resetBrightness
};

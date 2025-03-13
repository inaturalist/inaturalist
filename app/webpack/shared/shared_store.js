import _ from "lodash";
import "core-js/stable";
import "regenerator-runtime/runtime";
import thunkMiddleware from "redux-thunk";
import {
  createStore, compose, applyMiddleware, combineReducers
} from "redux";
import configReducer, { setCurrentUser } from "./ducks/config";

const staticReducers = {
  config: configReducer
};

const createReducer = asyncReducers => (
  combineReducers( {
    ...staticReducers,
    ...asyncReducers
  } )
);

const store = createStore(
  createReducer( ),
  compose( ..._.compact( [
    applyMiddleware( thunkMiddleware ),
    // enable Redux DevTools if available
    window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__()
  ] ) )
);

store.asyncReducers = { };

store.injectReducer = ( key, asyncReducer ) => {
  store.asyncReducers[key] = asyncReducer;
  store.replaceReducer( createReducer( store.asyncReducers ) );
};

store.injectReducers = reducers => {
  _.each( reducers, ( asyncReducer, key ) => {
    store.asyncReducers[key] = asyncReducer;
  } );
  store.replaceReducer( createReducer( store.asyncReducers ) );
};

if ( !_.isEmpty( CURRENT_USER ) ) {
  store.dispatch( setCurrentUser( CURRENT_USER ) );
}

export default store;

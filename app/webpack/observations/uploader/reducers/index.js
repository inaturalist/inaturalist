import { combineReducers } from "redux";
import dragDropZone from "./drag_drop_zone";
import savedLocations from "../ducks/saved_locations";
import config from "../../../shared/ducks/config";

const uploaderApp = combineReducers( {
  dragDropZone,
  savedLocations,
  config
} );

export default uploaderApp;

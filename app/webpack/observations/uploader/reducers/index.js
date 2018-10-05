import { combineReducers } from "redux";
import dragDropZone from "./drag_drop_zone";
import savedLocations from "../ducks/saved_locations";

const uploaderApp = combineReducers( {
  dragDropZone,
  savedLocations
} );

export default uploaderApp;

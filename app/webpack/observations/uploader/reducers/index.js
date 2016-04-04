import { combineReducers } from "redux";
import table from "./table";
import dragDropZone from "./drag_drop_zone";

const uploaderApp = combineReducers( {
  table,
  dragDropZone
} );

export default uploaderApp;

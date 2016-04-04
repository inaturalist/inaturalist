import * as types from "../constants/constants";

export const drag = ( draggedCol, targetCol ) => (
  { type: types.DRAG, draggedCol, targetCol }
);

export const uploadFiles = ( files ) => (
  { type: types.UPLOAD_FILES, files }
);

export const updateFile = ( file, attrs ) => (
  { type: types.UPDATE_FILE, file, attrs }
);

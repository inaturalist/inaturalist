import * as types from "../constants/constants";

const actions = class actions {

  static setState( attrs ) {
    return { type: types.SET_STATE, attrs };
  }

  static updateState( attrs ) {
    return { type: types.UPDATE_STATE, attrs };
  }

};

export default actions;

const UPDATE_SEARCH_PARAMS = "update_search_params";
const UPDATE_SEARCH_PARAMS_FROM_POP = "update_search_params_from_pop";
const UPDATE_DEFAULT_PARAMS = "update_default_params";

function updateSearchParams( params ) {
  return {
    type: UPDATE_SEARCH_PARAMS,
    params
  };
}

function updateSearchParamsFromPop( params ) {
  return {
    type: UPDATE_SEARCH_PARAMS_FROM_POP,
    params
  };
}

function updateDefaultParams( params ) {
  return {
    type: UPDATE_DEFAULT_PARAMS,
    params
  };
}

export {
  UPDATE_SEARCH_PARAMS,
  UPDATE_SEARCH_PARAMS_FROM_POP,
  UPDATE_DEFAULT_PARAMS,
  updateSearchParams,
  updateSearchParamsFromPop,
  updateDefaultParams
};

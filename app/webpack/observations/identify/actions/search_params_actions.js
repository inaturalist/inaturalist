const UPDATE_SEARCH_PARAMS = "update_search_params";
const UPDATE_SEARCH_PARAMS_FROM_POP = "update_search_params_from_pop";

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

export {
  UPDATE_SEARCH_PARAMS,
  UPDATE_SEARCH_PARAMS_FROM_POP,
  updateSearchParams,
  updateSearchParamsFromPop
};

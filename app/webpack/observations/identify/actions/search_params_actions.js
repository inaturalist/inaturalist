const UPDATE_SEARCH_PARAMS = "update_search_params";
const UPDATE_SEARCH_PARAMS_WITHOUT_HISTORY = "update_search_params_without_history";
const UPDATE_DEFAULT_PARAMS = "update_default_params";
const REPLACE_SEARCH_PARAMS = "replace_search_params";

function replaceSearchParams( params ) {
  return {
    type: REPLACE_SEARCH_PARAMS,
    params
  };
}

function updateSearchParams( params ) {
  return {
    type: UPDATE_SEARCH_PARAMS,
    params
  };
}

function updateSearchParamsWithoutHistory( params ) {
  return {
    type: UPDATE_SEARCH_PARAMS_WITHOUT_HISTORY,
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
  UPDATE_SEARCH_PARAMS_WITHOUT_HISTORY,
  UPDATE_DEFAULT_PARAMS,
  REPLACE_SEARCH_PARAMS,
  updateSearchParams,
  updateSearchParamsWithoutHistory,
  updateDefaultParams,
  replaceSearchParams
};

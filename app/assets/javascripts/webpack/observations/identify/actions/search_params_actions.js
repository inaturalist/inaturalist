const UPDATE_SEARCH_PARAMS = "update_search_params";

function updateSearchParams( params ) {
  return {
    type: UPDATE_SEARCH_PARAMS,
    params
  };
}

export {
  UPDATE_SEARCH_PARAMS,
  updateSearchParams
};

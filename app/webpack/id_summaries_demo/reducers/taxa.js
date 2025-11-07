import {
  TAXA_FETCH_REQUEST,
  TAXA_FETCH_SUCCESS,
  TAXA_FETCH_FAILURE
} from "../actions/taxa";

const initial = {
  loading: false,
  error: null,
  list: [],
  page: 1,
  perPage: 30,
  totalResults: 0
};

export default function taxa( state = initial, action ) {
  switch ( action.type ) {
    case TAXA_FETCH_REQUEST:
      return {
        ...state,
        loading: true,
        error: null,
        list: []
      };
    case TAXA_FETCH_SUCCESS:
      return {
        ...state,
        loading: false,
        error: null,
        list: action.payload.speciesList,
        page: action.payload.page,
        perPage: action.payload.perPage,
        totalResults: action.payload.totalResults
      };
    case TAXA_FETCH_FAILURE:
      return { ...state, loading: false, error: action.error || "Error" };
    default:
      return state;
  }
}

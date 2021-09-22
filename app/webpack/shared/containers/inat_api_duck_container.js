import _ from "lodash";
import { connect } from "react-redux";
import { searchWrapper } from "../ducks/inat_api_duck";
import { updateCurrentUser } from "../ducks/config";

export default function createWrapperContainer( searchKey, component ) {
  function mapStateToProps( state ) {
    return {
      config: state.config,
      search: _.get( state.inatAPI, searchKey )
    };
  }

  function mapDispatchToProps( dispatch ) {
    const wrapper = searchWrapper( searchKey );
    return {
      fetchFirstPage: ( ...args ) => dispatch( wrapper.fetchFirstPage( ...args ) ),
      fetchNextPage: ( ) => dispatch( wrapper.fetchNextPage( ) ),
      updateCurrentUser: user => dispatch( updateCurrentUser( user ) )
    };
  }

  return connect(
    mapStateToProps,
    mapDispatchToProps
  )( component );
}

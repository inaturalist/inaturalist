// Temporary gate for the responsive taxon detail page. Every component this branch
// rewrote keeps its original path and dispatches to a `*_legacy` sibling when the
// current user is not testing responsiveness, so containers need no rewiring.
//
// Reads the CURRENT_USER global rather than `config.currentUser` because most of the
// rewritten components are leaves that never receive `config`. Delete this module, the
// dispatchers, and every `*_legacy` file once responsiveness ships unconditionally.

const currentUser = ( ) => ( typeof CURRENT_USER === "undefined" ? null : CURRENT_USER );

const inTestGroup = ( group: string ): boolean => (
  currentUser( )?.testGroups?.includes( group ) === true
);

const taxaShowResponsive = ( ): boolean => (
  ( currentUser( )?.roles?.includes( "admin" ) === true && inTestGroup( "responsive-taxon-detail" ) )
  || inTestGroup( "web-984-pr4-taxa-show" )
);

export default taxaShowResponsive;

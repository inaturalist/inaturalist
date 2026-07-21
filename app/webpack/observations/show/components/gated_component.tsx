import React from "react";

interface WithConfig {
  config?: { currentUser?: { isInTestGroup?: ( group: string ) => boolean } };
}

// Renders the responsive (new) implementation for users in the
// responsive-obs-detail test group and the legacy (pre-responsive) one for
// everyone else. Both variants receive the same connected props, so the choice
// is transparent to the container. Remove once the responsive page ships to all.
function gatedComponent<P extends WithConfig>(
  Responsive: React.ComponentType<P>,
  Legacy: React.ComponentType<P>
): React.FC<P> {
  return function GatedComponent( props: P ) {
    const Chosen = props.config?.currentUser?.isInTestGroup?.( "responsive-obs-detail" )
      ? Responsive
      : Legacy;
    return React.createElement( Chosen, props );
  };
}

export default gatedComponent;

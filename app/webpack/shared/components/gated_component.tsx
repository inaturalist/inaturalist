import React from "react";

interface WithConfig {
  config?: { currentUser?: { isInTestGroup?: ( group: string ) => boolean } };
}

function gatedComponent<P extends WithConfig>(
  testGroups: string[],
  InGroup: React.ComponentType<P>,
  Fallback: React.ComponentType<P>
): React.FC<P> {
  return function GatedComponent( props: P ) {
    const user = props.config?.currentUser;
    const inGroup = testGroups.some( group => user?.isInTestGroup?.( group ) );
    return React.createElement( inGroup ? InGroup : Fallback, props );
  };
}

export default gatedComponent;

import React from "react";

interface User { testGroups?: string[] }
interface GatedProps {
  config?: { currentUser?: User };
  currentUser?: User;
}

// Prefers the connected user, whether the container maps it as `config` or `currentUser`,
// and falls back to the Rails-injected global for containers that map neither.
const userTestGroups = ( props: GatedProps ): string[] | undefined => (
  props.config?.currentUser?.testGroups
  ?? props.currentUser?.testGroups
  ?? ( typeof CURRENT_USER === "undefined" ? undefined : CURRENT_USER?.testGroups )
);

function gatedComponent<P extends object>(
  testGroups: string[],
  InGroup: React.ComponentType<P>,
  Fallback: React.ComponentType<P>
): React.FC<P> {
  return function GatedComponent( props: P ) {
    const groups = userTestGroups( props as GatedProps );
    const inGroup = testGroups.some( group => groups?.includes( group ) );
    return React.createElement( inGroup ? InGroup : Fallback, props );
  };
}

export default gatedComponent;

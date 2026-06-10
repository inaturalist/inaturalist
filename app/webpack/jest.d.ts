// Makes Jest's ambient globals (describe/it/expect/jest) and @testing-library/jest-dom
// matchers (toBeInTheDocument, toHaveAttribute, …) visible to tsc for the colocated
// *.test.tsx files. The repo references ambient @types the same way in globals.d.ts.
/// <reference types="jest" />
/// <reference types="@testing-library/jest-dom" />

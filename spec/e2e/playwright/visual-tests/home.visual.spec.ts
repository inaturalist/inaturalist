import { expectVisualSnapshots } from "./helpers/visual-snapshot.helper";

expectVisualSnapshots( "home", "/home", {
  mask: page => [page.locator( ".UserPhoto img" )]
} );

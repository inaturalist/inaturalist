import React from "react";
import { render } from "react-dom";
import TabDrawer from "../../shared/components/tab_drawer";

const el = document.querySelector( "#UserSubnavTabDrawer" );
if ( el ) {
  const items = JSON.parse( el.dataset.items );
  const selectedValue = el.dataset.selectedValue;
  render( <TabDrawer items={items} selectedValue={selectedValue} />, el );
}

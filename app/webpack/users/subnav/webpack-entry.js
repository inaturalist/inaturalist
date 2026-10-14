import React from "react";
import { render } from "react-dom";
import TabDropdown from "../../shared/components/tab_dropdown";

const el = document.querySelector( "#UserSubnavTabDropdown" );
if ( el ) {
  const items = JSON.parse( el.dataset.items );
  const selectedValue = el.dataset.selectedValue;
  render( <TabDropdown items={items} selectedValue={selectedValue} />, el );
}

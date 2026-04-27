import React, { useState } from "react";

interface TabItem {
  value: string;
  label: string;
}

interface TabDrawerProps {
  selectedValue?: string;
  selectedLabel?: string;
  items?: TabItem[];
  onChange?: ( value: string ) => void;
}

const TabDrawer = ( {
  selectedValue, selectedLabel, items = [], onChange
}: TabDrawerProps ) => {
  const [open, setOpen] = useState( false );

  return (
    <div className={`tab-drawer-container${open ? " open" : ""}`}>
      <button
        type="button"
        className="tab-drawer-toggle"
        aria-expanded={open}
        aria-controls="tab-drawer"
        onClick={() => setOpen( o => !o )}
      >
        { selectedLabel }
        <i className={`fa fa-chevron-${open ? "up" : "down"}`} />
      </button>
      <ul id="tab-drawer" className="tab-drawer">
        { items
          .filter( item => item.value !== selectedValue )
          .map( item => (
            <li key={item.value}>
              <button
                type="button"
                onClick={() => { if ( onChange ) onChange( item.value ); setOpen( false ); }}
              >
                { item.label }
              </button>
            </li>
          ) )}
      </ul>
    </div>
  );
};

export default TabDrawer;

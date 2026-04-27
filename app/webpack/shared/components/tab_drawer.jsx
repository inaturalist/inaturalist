import React, { useState } from "react";
import PropTypes from "prop-types";

const TabDrawer = ( {
  selectedValue, selectedLabel, items, onChange
} ) => {
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
                onClick={() => { onChange( item.value ); setOpen( false ); }}
              >
                { item.label }
              </button>
            </li>
          ) )}
      </ul>
    </div>
  );
};

TabDrawer.propTypes = {
  selectedValue: PropTypes.string,
  selectedLabel: PropTypes.string,
  items: PropTypes.arrayOf( PropTypes.shape( {
    value: PropTypes.string,
    label: PropTypes.string
  } ) ),
  onChange: PropTypes.func
};

export default TabDrawer;

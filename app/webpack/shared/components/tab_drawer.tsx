import React, { useState } from "react";

interface TabItem {
  value?: string;
  label?: string;
  href?: string;
  onClick?: ( ) => void;
  separator?: boolean;
  icon?: string;
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
          .filter( item => item.separator || item.value !== selectedValue )
          .map( ( item, i ) => {
            if ( item.separator ) {
              // eslint-disable-next-line react/no-array-index-key
              return <li key={`sep-${i}`} className="tab-drawer-separator" />;
            }
            const itemIcon = item.icon
              ? <i className={`fa ${item.icon} tab-drawer-item-icon`} />
              : null;
            if ( item.href ) {
              return (
                <li key={item.href}>
                  <a href={item.href} onClick={() => setOpen( false )}>
                    { itemIcon }
                    { item.label }
                  </a>
                </li>
              );
            }
            if ( item.onClick ) {
              return (
                <li key={item.label}>
                  <button
                    type="button"
                    onClick={() => { item.onClick!( ); setOpen( false ); }}
                  >
                    { itemIcon }
                    { item.label }
                  </button>
                </li>
              );
            }
            return (
              <li key={item.value}>
                <button
                  type="button"
                  onClick={() => { if ( onChange ) onChange( item.value! ); setOpen( false ); }}
                >
                  { itemIcon }
                  { item.label }
                </button>
              </li>
            );
          } )}
      </ul>
    </div>
  );
};

export default TabDrawer;

import React, { useState } from "react";
import css from "./tab_drawer.module.css";

interface TabItem {
  value: string;
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
    <div className={`${css.container}${open ? ` ${css.open}` : ""}`}>
      <button
        type="button"
        className={css.toggle}
        aria-expanded={open}
        aria-controls="tab-drawer"
        onClick={() => setOpen( o => !o )}
      >
        { selectedLabel }
        <i className={`fa fa-chevron-${open ? "up" : "down"}`} />
      </button>
      <ul id="tab-drawer" className={css.drawer}>
        { items
          .filter( item => item.separator || item.value !== selectedValue )
          .map( item => {
            if ( item.separator ) {
              return <li key={item.value} className={css.separator} />;
            }
            const itemIcon = item.icon
              ? <i className={`fa ${item.icon} ${css["item-icon"]}`} />
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

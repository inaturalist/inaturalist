import React, { useState } from "react";
import _ from "lodash";
import css from "./tab_drawer.module.css";

interface TabItemBase {
  value: string;
  label: string;
  icon?: string;
}

export type TabItem =
  | { kind: "separator"; value: string }
  | ( TabItemBase & { kind: "tab" } )
  | ( TabItemBase & { kind: "link"; href: string } )
  | ( TabItemBase & { kind: "action"; onClick: ( ) => void } );

interface TabDrawerProps {
  selectedValue?: string;
  items?: TabItem[];
  onChange?: ( value: string ) => void;
}

const TabDrawer = ( {
  selectedValue, items = [], onChange
}: TabDrawerProps ) => {
  const [open, setOpen] = useState( false );
  // Unique per instance so multiple drawers on one page don't collide on the DOM id.
  const [drawerId] = useState( ( ) => _.uniqueId( "tab-drawer-" ) );

  const selectedItem = items.find(
    ( item ): item is Exclude<TabItem, { kind: "separator" }> => (
      item.kind !== "separator" && item.value === selectedValue
    )
  );

  return (
    <div className={`${css.container}${open ? ` ${css.open}` : ""}`}>
      <button
        type="button"
        className={css.toggle}
        aria-expanded={open}
        aria-controls={drawerId}
        onClick={() => setOpen( o => !o )}
      >
        <div>
          { selectedItem?.icon && <i className={`${selectedItem.icon} ${css["item-icon"]}`} /> }
          { selectedItem?.label }
        </div>
        <i className={`fa fa-chevron-${open ? "up" : "down"}`} />
      </button>
      <ul id={drawerId} className={css.drawer}>
        { items
          .filter( item => item.kind === "separator" || item.value !== selectedValue )
          .map( item => {
            if ( item.kind === "separator" ) {
              return <li key={item.value} className={css.separator} />;
            }
            const itemIcon = item.icon
              ? <i className={`${item.icon} ${css["item-icon"]}`} />
              : null;
            if ( item.kind === "link" ) {
              return (
                <li key={item.value}>
                  <a href={item.href} onClick={() => setOpen( false )}>
                    { itemIcon }
                    { item.label }
                  </a>
                </li>
              );
            }
            if ( item.kind === "action" ) {
              return (
                <li key={item.value}>
                  <button
                    type="button"
                    onClick={() => { item.onClick( ); setOpen( false ); }}
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
                  onClick={() => { if ( onChange ) onChange( item.value ); setOpen( false ); }}
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

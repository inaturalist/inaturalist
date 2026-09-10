/* eslint-disable react/jsx-props-no-spreading */
// react-aria hands back prop objects; spreading them onto our own JSX is the whole interface.
import React, {
  useCallback, useEffect, useMemo, useRef, useState
} from "react";
import {
  DismissButton,
  Overlay,
  useComboBox,
  useListBox,
  useListBoxSection,
  useOption,
  usePopover
} from "react-aria";
import { Item, Section, useComboBoxState } from "react-stately";
import type { AriaListBoxOptions } from "react-aria";
import type { ComboBoxState } from "react-stately";
import type { Node } from "@react-types/shared";
import css from "./combobox.module.css";

export interface ComboboxOption {
  key: string;
  // Written into the input when the option is chosen; pass the current query to leave it alone.
  textValue: string;
  content: React.ReactNode;
  group?: string;
  className?: string;
  keepMenuOpenOnSelect?: boolean;
}

export interface ComboboxGroup {
  key: string;
  title: React.ReactNode;
}

export interface ComboboxProps {
  label: string;
  options: ComboboxOption[];
  inputValue: string;
  onInputChange: ( value: string ) => void;
  onSearch: ( query: string ) => void;
  onSelect: ( option: ComboboxOption ) => void;
  groups?: ComboboxGroup[];
  header?: React.ReactNode;
  message?: React.ReactNode;
  footer?: React.ReactNode;
  startAddon?: React.ReactNode;
  onClear?: ( ) => void;
  clearLabel?: string;
  placeholder?: string;
  minLength?: number;
  delay?: number;
  className?: string;
  inputClassName?: string;
  inputName?: string;
  onInputKeyDown?: ( event: React.KeyboardEvent<HTMLInputElement> ) => void;
}

interface OptionProps {
  item: Node<ComboboxOption>;
  state: ComboBoxState<ComboboxOption>;
  optionsByKey: Map<string, ComboboxOption>;
}

const Option = ( { item, state, optionsByKey }: OptionProps ) => {
  const ref = useRef<HTMLLIElement>( null );
  const { optionProps, isFocused } = useOption( { key: item.key }, state, ref );
  const option = optionsByKey.get( String( item.key ) );
  const classNames = [css.option, option?.className, isFocused && css.optionFocused];
  return (
    <li {...optionProps} ref={ref} className={classNames.filter( Boolean ).join( " " )}>
      { item.rendered }
    </li>
  );
};

interface SectionProps {
  section: Node<ComboboxOption>;
  state: ComboBoxState<ComboboxOption>;
  optionsByKey: Map<string, ComboboxOption>;
}

const ListBoxSection = ( { section, state, optionsByKey }: SectionProps ) => {
  const { itemProps, headingProps, groupProps } = useListBoxSection( {
    heading: section.rendered,
    "aria-label": section["aria-label"]
  } );
  return (
    <li {...itemProps} className={css.section}>
      <div {...headingProps} className={css.category}>{ section.rendered }</div>
      <ul {...groupProps} className={css.sectionList}>
        { [...section.childNodes].map( node => (
          <Option key={node.key} item={node} state={state} optionsByKey={optionsByKey} />
        ) ) }
      </ul>
    </li>
  );
};

interface ListBoxProps {
  listBoxProps: AriaListBoxOptions<ComboboxOption>;
  listBoxRef: React.RefObject<HTMLUListElement>;
  state: ComboBoxState<ComboboxOption>;
  optionsByKey: Map<string, ComboboxOption>;
}

const ListBox = ( {
  listBoxProps, listBoxRef, state, optionsByKey
}: ListBoxProps ) => {
  const { listBoxProps: ulProps } = useListBox( listBoxProps, state, listBoxRef );
  return (
    <ul {...ulProps} ref={listBoxRef} className={css.list}>
      { [...state.collection].map( node => ( node.type === "section"
        ? (
          <ListBoxSection
            key={node.key}
            section={node}
            state={state}
            optionsByKey={optionsByKey}
          />
        )
        : <Option key={node.key} item={node} state={state} optionsByKey={optionsByKey} /> ) ) }
    </ul>
  );
};

interface PopoverProps {
  state: ComboBoxState<ComboboxOption>;
  triggerRef: React.RefObject<HTMLElement>;
  popoverRef: React.RefObject<HTMLDivElement>;
  children: React.ReactNode;
}

const Popover = ( {
  state, triggerRef, popoverRef, children
}: PopoverProps ) => {
  const { popoverProps } = usePopover( {
    triggerRef,
    popoverRef,
    isNonModal: true,
    placement: "bottom start",
    offset: 4,
    containerPadding: 0
  }, state );
  const style = { ...popoverProps.style, width: triggerRef.current?.offsetWidth };
  return (
    <Overlay>
      <div {...popoverProps} ref={popoverRef} className={css.popup} style={style}>
        <DismissButton onDismiss={state.close} />
        { children }
        <DismissButton onDismiss={state.close} />
      </div>
    </Overlay>
  );
};

const Combobox = ( {
  label,
  options,
  inputValue,
  onInputChange,
  onSearch,
  onSelect,
  groups = [],
  header,
  message,
  footer,
  startAddon,
  onClear,
  clearLabel,
  placeholder,
  minLength = 1,
  delay = 250,
  className = "",
  inputClassName = "",
  inputName,
  onInputKeyDown
}: ComboboxProps ) => {
  const inputRef = useRef<HTMLInputElement>( null );
  const listBoxRef = useRef<HTMLUListElement>( null );
  const popoverRef = useRef<HTMLDivElement>( null );
  const fieldRef = useRef<HTMLDivElement>( null );
  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>( null );
  const stateRef = useRef<ComboBoxState<ComboboxOption> | null>( null );
  const [selectedKey, setSelectedKey] = useState<React.Key | null>( null );

  const optionsByKey = useMemo(
    ( ) => new Map( options.map( option => [option.key, option] ) ),
    [options]
  );

  const children = useMemo( ( ) => {
    const renderOption = ( option: ComboboxOption ) => (
      <Item key={option.key} textValue={option.textValue}>{ option.content }</Item>
    );
    const sections = groups
      .map( group => ( { group, members: options.filter( o => o.group === group.key ) } ) )
      .filter( ( { members } ) => members.length > 0 )
      .map( ( { group, members } ) => (
        <Section key={group.key} title={group.title}>{ members.map( renderOption ) }</Section>
      ) );
    return [...sections, ...options.filter( o => !o.group ).map( renderOption )];
  }, [options, groups] );

  const search = useCallback( ( query: string, immediate: boolean ) => {
    if ( searchTimer.current ) { clearTimeout( searchTimer.current ); }
    if ( query.length < minLength ) { return; }
    if ( immediate ) {
      onSearch( query );
      return;
    }
    searchTimer.current = setTimeout( ( ) => onSearch( query ), delay );
  }, [minLength, delay, onSearch] );

  useEffect( ( ) => ( ) => {
    if ( searchTimer.current ) { clearTimeout( searchTimer.current ); }
  }, [] );

  const handleSelectionChange = ( key: React.Key | null ) => {
    setSelectedKey( key );
    const option = key === null ? undefined : optionsByKey.get( String( key ) );
    if ( !option ) { return; }
    onInputChange( option.textValue );
    onSelect( option );
    // Selection closes the menu; reopen it for options that kick off a follow-up search.
    if ( option.keepMenuOpenOnSelect ) {
      requestAnimationFrame( ( ) => stateRef.current?.open( ) );
    }
  };

  const sharedProps = {
    label,
    placeholder,
    inputValue,
    onInputChange,
    value: selectedKey,
    onChange: handleSelectionChange,
    allowsEmptyCollection: true,
    allowsCustomValue: true,
    menuTrigger: "focus" as const
  };

  const state = useComboBoxState<ComboboxOption>( { ...sharedProps, children } );
  stateRef.current = state;
  const { inputProps, listBoxProps, labelProps } = useComboBox<ComboboxOption>( {
    ...sharedProps,
    name: inputName,
    inputRef,
    listBoxRef,
    popoverRef
  }, state );

  const hasPopupContent = options.length > 0 || !!header || !!message || !!footer;

  return (
    <div className={`${css.combobox} ${className}`}>
      <label {...labelProps} className={css.srOnly}>{ label }</label>
      <div className={css.field} ref={fieldRef}>
        { startAddon && <div className={css.addon}>{ startAddon }</div> }
        <input
          {...inputProps}
          ref={inputRef}
          className={`${css.input} ${inputClassName}`}
          onChange={event => {
            search( event.target.value, false );
            inputProps.onChange?.( event );
          }}
          onFocus={event => {
            inputProps.onFocus?.( event );
            search( inputValue, true );
          }}
          onKeyDown={event => {
            inputProps.onKeyDown?.( event );
            onInputKeyDown?.( event );
          }}
        />
        { onClear && inputValue && (
          <button
            type="button"
            className={css.clear}
            aria-label={clearLabel || label}
            onClick={( ) => {
              setSelectedKey( null );
              state.close( );
              onClear( );
            }}
          >
            <span className="glyphicon glyphicon-remove-circle" aria-hidden="true" />
          </button>
        ) }
      </div>
      { state.isOpen && hasPopupContent && (
        <Popover state={state} triggerRef={fieldRef} popoverRef={popoverRef}>
          { header && <div className={css.message}>{ header }</div> }
          <ListBox
            listBoxProps={listBoxProps}
            listBoxRef={listBoxRef}
            state={state}
            optionsByKey={optionsByKey}
          />
          { message && <div className={css.message}>{ message }</div> }
          { footer && <div className={css.footer}>{ footer }</div> }
        </Popover>
      ) }
    </div>
  );
};

export default Combobox;

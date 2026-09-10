/* eslint-disable react/jsx-props-no-spreading */
// react-aria hands back prop objects; spreading them onto our own JSX is the whole interface.
import React, {
  useCallback, useEffect, useMemo, useRef, useState
} from "react";
import {
  useComboBox,
  useInteractOutside,
  useListBox,
  useListBoxSection,
  useOption
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
  keepMenuOnBlur?: boolean;
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
  keepMenuOnBlur = false,
  className = "",
  inputClassName = "",
  inputName,
  onInputKeyDown
}: ComboboxProps ) => {
  const inputRef = useRef<HTMLInputElement>( null );
  const listBoxRef = useRef<HTMLUListElement>( null );
  const popoverRef = useRef<HTMLDivElement>( null );
  const wrapperRef = useRef<HTMLDivElement>( null );
  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>( null );
  const suppressSearch = useRef( false );
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
    if ( !option.keepMenuOpenOnSelect ) {
      suppressSearch.current = true;
      inputRef.current?.blur( );
    }
    onSelect( option );
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
    shouldCloseOnBlur: !keepMenuOnBlur,
    menuTrigger: "focus" as const
  };

  const state = useComboBoxState<ComboboxOption>( { ...sharedProps, children } );
  const { inputProps, listBoxProps, labelProps } = useComboBox<ComboboxOption>( {
    ...sharedProps,
    name: inputName,
    inputRef,
    listBoxRef,
    popoverRef
  }, state );

  useInteractOutside( {
    ref: wrapperRef,
    onInteractOutside: ( ) => {
      state.close( );
      state.setFocused( false );
    }
  } );

  const hasPopupContent = options.length > 0 || !!header || !!message || !!footer;

  return (
    <div className={`${css.combobox} ${className}`} ref={wrapperRef}>
      <label {...labelProps} className={css.srOnly}>{ label }</label>
      <div className={css.field}>
        { startAddon && <div className={css.addon}>{ startAddon }</div> }
        <input
          {...inputProps}
          ref={inputRef}
          className={`${css.input} ${inputClassName}`}
          onChange={event => {
            suppressSearch.current = false;
            search( event.target.value, false );
            inputProps.onChange?.( event );
          }}
          onFocus={event => {
            inputProps.onFocus?.( event );
            if ( !suppressSearch.current ) { search( inputValue, true ); }
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
              suppressSearch.current = false;
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
        <div className={css.popup} ref={popoverRef}>
          { header && <div className={css.message}>{ header }</div> }
          <ListBox
            listBoxProps={listBoxProps}
            listBoxRef={listBoxRef}
            state={state}
            optionsByKey={optionsByKey}
          />
          { message && <div className={css.message}>{ message }</div> }
          { footer && <div className={css.footer}>{ footer }</div> }
        </div>
      ) }
    </div>
  );
};

export default Combobox;

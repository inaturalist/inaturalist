import React from "react";
import { Input, Button } from "react-bootstrap";

const SearchBar = () => (
  <form className="form-inline">
    {/* Taxon AutoComplete should really be it's own component that takes callbacks as props */}
    <Input
      type="search"
      name="taxon_name"
      className="form-control"
      placeholder={ I18n.t( "species" ) }
    />
    {/* Same here */}
    <Input
      type="text"
      name="place_name"
      className="form-control"
      placeholder={ I18n.t( "place" ) }
    />
    <Button bsStyle="primary">{ I18n.t( "go" ) }</Button>
    <Button>{ I18n.t( "filters" ) }</Button>
    <Input type="checkbox" label={ I18n.t( "reviewed" ) } />
  </form>
);

export default SearchBar;

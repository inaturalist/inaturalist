import React, { Component } from "react";
import { Table, Button } from "react-bootstrap"; // ✅ Using React-Bootstrap
import SplitTaxon from "../../../shared/components/split_taxon";
import util from "../../../observations/show/util";

class SpeciesTableApp extends Component {
  constructor(props) {
    super(props);
    this.state = {
      data: props.stats_data || [],
      currentUser: props.currentUser || [],
      sortConfig: { key: "taxon", direction: "asc" },
    };
  }

  handleSort = (key) => {
    const { sortConfig, data } = this.state;
    let direction = "asc";

    if (sortConfig?.key === key && sortConfig.direction === "asc") {
      direction = "desc";
    }

    const sortedData = [...data].sort((a, b) => {
      if (a[key] < b[key]) return direction === "asc" ? -1 : 1;
      if (a[key] > b[key]) return direction === "asc" ? 1 : -1;
      return 0;
    });

    this.setState({ data: sortedData, sortConfig: { key, direction } });
  };

  renderSortIndicator = (key) => {
    const { sortConfig } = this.state;
    if (sortConfig.key === key) {
      return sortConfig.direction === "asc" ? " ▲" : " ▼";
    }
    return "";
  };

  render() {
    return (
      <div className="container mt-4">
        <Table striped bordered hover>
          <thead>
            <tr>
              <th>#</th> {/* ✅ Rank column */}
              <th>
                <Button variant="link" onClick={() => this.handleSort("taxon")}>
                  Taxon {this.renderSortIndicator("taxon")}
                </Button>
              </th>
              <th>
                <Button variant="link" onClick={() => this.handleSort("country")}>
                  Country {this.renderSortIndicator("taxon")}
                </Button>
              </th>
              <th>
                <Button variant="link" onClick={() => this.handleSort("obs_count_at_creation")}>
                  Observation Rank {this.renderSortIndicator("obs_count_at_creation")}
                </Button>
              </th>
              <th>
                <Button variant="link" onClick={() => this.handleSort("obs_country_count_at_creation")}>
                  Observation Rank in Country {this.renderSortIndicator("obs_country_count_at_creation")}
                </Button>
              </th>
            </tr>
          </thead>
          <tbody>
            {this.state.data.map((item, index) => (
              <tr key={index}>
                <td>{index + 1}</td> {/* ✅ Rank column (always 1 to X) */}
                <td>
                  <div className="photo">
                    <a
                      href={`/taxa/${item.taxon_id}`}
                    >
                      {util.taxonImage( item.taxon )}
                    </a>
                  </div>
                  <div className="name">
                    <a
                      href={`/taxa/${item.taxon_id}`}
                    >
                      {item.taxon}
                    </a>
                  </div>
                </td>
                <td>{item.country}</td>
                <td>{item.obs_count_at_creation} / {item.obs_count}</td>
                <td>{item.obs_country_count_at_creation} / {item.obs_country_count}</td>
              </tr>
            ))}
          </tbody>
        </Table>
      </div>
    );
  }
}

export default SpeciesTableApp;

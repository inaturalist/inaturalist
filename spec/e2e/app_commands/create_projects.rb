# frozen_string_literal: true

# Projects browse reads from Elasticsearch, so created projects must be indexed explicitly.
#
#   app( "create_projects", { titles: ["First", "Second"] } )
projects = command_options["titles"].map {| title | Project.make!( title: title ) }
Project.elastic_index!( ids: projects.map( &:id ) )
projects

#1. Means to distinguish multiple listed taxa with the same taxon & place
#https://github.com/inaturalist/inaturalist/issues/196
# For this issue, you'll need 2 listed taxa belonging to the same taxon and place, but different lsits

def read_json( filename, obj, options = {} )
  f = File.open( filename, "r" )
  json_data = JSON.load(f) 
  data = JSON.parse(json_data)
  data.map { |a| obj[a[0]] = a[1] }
  options.map{ |a| obj[a[0]] = a[1] }
  if obj.class == PlaceGeometry # Hack for issue with the way geom is encoded
    dat_string = data["geom"].to_s
    dat_string_alt = dat_string.gsub("=>",":")
    obj.geom = GeoRuby::SimpleFeatures::Geometry.from_geojson(dat_string_alt)
  end
  obj.save
  return obj
end

#uncomment to clear out DB
User.destroy_all
Role.destroy_all
Source.destroy_all
Place.destroy_all
Place_Geometry.destroy_all
Taxon.destroy_all
TaxonName.destroy_all
List.destroy_all
ListedTaxon.destroy_all

##need a user, roles, and a source
user = User.new(
  :login => "john_doe",
  :email => "john_doe@inaturalist.org",
  :password => "changeme",
  :password_confirmation => "changeme"
)

#now create some roles
curator_role = Role.new(
  :name => "curator"
)
curator_role.save

admin_role = Role.new(
  :name => "admin"
)
admin_role.save

user.roles << curator_role
user.roles << admin_role
user.save

source = Source.new(
  :in_text => "NPSpecies, 2013",
  :citation => "https://irma.nps.gov/App/Species/Search",
  :url => "https://irma.nps.gov/App/Species/Search", 
  :title => "NPSpecies",
  :user_id => user.id
)
source.save

##need a place
filenames = ["place.json", "place_8.json", "place_12.json", "place_29.json"]
filenames.each do |fn|
  obj = Place.new
  options = { :source_id => source.id }
  place = read_json( fn, obj, options )
  
  fn = fn.gsub("place", "place_geometry")
  obj = PlaceGeometry.new  
  options = { :source_id => source.id }
  place_geometry = read_json( fn, obj, options )
end

##need some taxa and names
filenames = ["taxon_stateofmatter.json","taxon_kingdom.json","taxon_superphylum.json","taxon_phylum.json","taxon_class.json","taxon_order.json","taxon_family.json","taxon_genus.json","taxon.json"]
filenames.each do |fn|
  obj = Taxon.new
  options = { :source_id => source.id }
  taxon = read_json( fn, obj, options )
  
  unless fn == "taxon_stateofmatter.json" || fn == "taxon_order.json"
    fn = fn.gsub(".json", "_name.json")
    obj = TaxonName.new
    options = { :source_id => source.id }
    taxon_name = read_json( fn, obj, options )
  end
end

taxon = Taxon.where(:name => "Croton setigerus").first
place = Place.where(:name => "Golden Gate National Recreation Area").first

##need default list
default_checklist = CheckList.where(:id => place.check_list_id).first

##need some other list
other_list = CheckList.new(
  :title => "Plants of GGNRA",
  :description => "checklist of GGNRA plants",
  :user_id => user.id,
  :taxon_id => taxon.iconic_taxon_id,
  :place_id => place.id,
  :source_id => source.id
)
other_list.save

##need 2 listed taxa, one for each list
lt1 = ListedTaxon.new(
  :list_id => default_checklist.id,
  :taxon_id => taxon.id,
  :place_id => place.id,
  :user_id => user.id
)
lt1.save

lt2 = ListedTaxon.new(
  :list_id => other_list.id,
  :taxon_id => taxon.id,
  :place_id => place.id,
  :user_id => user.id
)
lt2.save

#2. More Checklist filters
#https://github.com/inaturalist/inaturalist/issues/198

#3. Make counts reflect filters on checklist barchart
#https://github.com/inaturalist/inaturalist/issues/200

#4. Find listed_taxa from a place not on a specific checklist
#https://github.com/inaturalist/inaturalist/issues/202

#5. Tailor Add Batch observation tool to projects
#https://github.com/inaturalist/inaturalist/issues/203

#6. Make curator IDs override observation.taxon_id for taxa filter on project obs search
#https://github.com/inaturalist/inaturalist/issues/204

#7. Make curator IDs override obs.taxon_id for generation of listed_taxa on project lists
#https://github.com/inaturalist/inaturalist/issues/205

#8. Display listed_taxa from place checklists on project lists
#https://github.com/inaturalist/inaturalist/issues/206


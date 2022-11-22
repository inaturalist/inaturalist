OPTS = Optimist::options do
    banner <<-EOS

Create a FrequencyCell grid of the globe and populate each cell with its respective
FrequencyCellMonthTaxon, broken out by month observed. The all_taxa_counts API will
return leaf-style counts, and will include accumulation counts for all ancestors
up the taxonomic tree. This can generate 3 times as much data compared to just storing
leaves, so there is a final step to only keep counts of species and non-species
leaf taxa included in a vision export

Usage:

  rails runner tools/frequency_cells_populate.rb

EOS
end

FrequencyCell.populate

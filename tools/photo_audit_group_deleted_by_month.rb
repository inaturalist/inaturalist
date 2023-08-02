require 'csv'

ids_csv_file_path = '/home/inaturalist/audit/photo_ids.XXXX.csv'
processed_csv_file_path = '/home/inaturalist/audit/counts_by_month.XXXX.csv'
batch_size = 1000

counts_by_month = Hash.new

batch_index = 0

# Process each batch of rows
CSV.foreach( ids_csv_file_path, headers: false ).each_slice( batch_size ) do |batch_rows|
  
  puts "#{batch_index}"
  batch_index += 1

  batch_ids = []

  batch_rows.each do |row|
    batch_ids << row[0].to_i
  end

  counts = DeletedPhoto.where( photo_id: batch_ids )
  .group( "DATE_TRUNC('month',created_at)" )
  .count

  counts.each do |k, v|
  	if counts_by_month.key?( k ) 
  		counts_by_month[k] += v
  	else
  		counts_by_month[k] = v
  	end
  end

end

puts counts_by_month

CSV.open( processed_csv_file_path, "w" ) do |processed_csv|
	counts_by_month.each do |k, v|
		processed_csv << [k,v]
	end
end




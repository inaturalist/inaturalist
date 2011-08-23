# run this with ruby, not runner!
last = Dir.glob('place_wkts/*').sort.last
max = last[/(\d+).wkt/, 1].to_i
(1..max).each_slice(200) do |slice|
  puts "== BATCH #{slice.first} - #{slice.last} ============================"
  system "ruby script/runner tools/place_geometries_from_wkt.rb #{slice.first} #{slice.last}"
  puts
end

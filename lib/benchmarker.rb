# Utilitity for benchmarking code in the console. Use it like this:
#
# Benchmarker.benchmark do |b|
#   b.benchmark "thing 1" do
#     # do thing 1
#   end
#   b.benchmark "thing 2" do
#     # do thing 1
#   end
# end
#
# Every time you call `b.benchmark "thing 1"` the time of the block will be
# recorded and stats about how long "thing 1" calls took will be reported at the
# end
class Benchmarker
  attr_accessor :benchmarks
  def benchmark( name, options = {} )
    @round = options[:round] ||= 4
    start = Time.now
    r = yield
    self.benchmarks ||= {}
    benchmarks[name] ||= []
    benchmarks[name] << Time.now - start
    r
  end

  def summarize( options = {} )
    sort_by = options.delete(:sort_by)
    return if benchmarks.blank?

    max_len = benchmarks.keys.map(&:size).max
    puts "**** BENCHMARKS ******************************************************"
    puts "#{"".ljust( max_len )} #{%w(n min max avg total).map{|m| m.rjust( 10 )}.join( " " )}"
    marks = benchmarks.clone
    if sort_by
      marks = marks.to_a.sort_by do |key, times|
        case sort_by.to_sym
        when :n then 
        when :min then times.min
        when :max then times.max
        when :total then times.sum
        when :avg then times.sum.to_f / times.size
        else key
        end
      end
    end
    marks.each do |key, times|
      n = times.size
      min = times.min
      max = times.max
      total = times.sum
      avg = total.to_f / times.size
      puts "#{key.ljust( max_len )} #{[n, min, max, avg, total].map{|m| m.round( @round ).to_s.rjust( 10 )}.join( " " )}"
    end
    puts "**** /BENCHMARKS ******************************************************"
  end

  def self.benchmark
    start = Time.now
    b = new
    yield b
    b.summarize
    puts
    puts "TOTAL: #{Time.now - start}"
    puts
    b
  end
end

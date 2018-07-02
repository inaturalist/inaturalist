require 'rubygems'
require 'trollop'

@opts = Trollop::options do
    banner <<-EOS
Calculate streaks of observations to find out who the regulars are. The
really, really regulars. A streak is defined as 3 days or more.

Usage:
  rails runner tools/streaks.rb [ -b added|observed -f text|csv ]

Options:
EOS
  opt :date, "Date to base streak on. Options: added, observed.", short: "-d", type: :string, default: 'observed_on'
  opt :format, "Output format, defaults to showing tables in the terminal. Options: csv|normal", short: "-f", type: :string, default: 'normal'
  opt :start_date, "Date to start counting from, YYYY-MM-DD format", short: "-s", type: :string, default: '2008-01-01'
  opt :increment, "Day or week. Default: day", short: "-i", type: :string, default: 'day'
end

streaks = [
  # {
  #   login: login, 
  #   units: nubmer_of_time_units_in_streak,
  #   start: date_of_streak_start,
  #   stop: date_of_streak_stop
  # } 
]
current_streaks = {
  # login: units
}
gaps = []
previous_logins = []
start_date = Time.parse(@opts.start_date)
increment = @opts.increment == 'day' ? 1.day : 7.days
# (start_date..Date.tomorrow).each do |date|
while start_date < 1.day.from_now
  date = start_date.to_date
  query = if @opts.date == 'added'
    "SELECT DISTINCT login FROM observations o JOIN users u ON u.id = o.user_id WHERE o.created_at BETWEEN '#{date}' AND '#{date + increment}'"
  else
    "SELECT DISTINCT login FROM observations o JOIN users u ON u.id = o.user_id WHERE o.observed_on BETWEEN '#{date}' AND '#{date + increment}'"
  end
  rows = Observation.connection.execute(query)
  logins = rows.map{|r| r['login']}
  gaps << date if logins.blank? && date != Date.tomorrow
  logins.each do |streaking_login|
    current_streaks[streaking_login] ||= 0
    current_streaks[streaking_login] += 1
  end
  (previous_logins - logins).each do |finished_login|
    if current_streaks[finished_login] >= 3
      streaks << {
        login: finished_login, 
        days: current_streaks[finished_login], 
        stop: date, 
        start: date-current_streaks[finished_login].days
      }
    end
    current_streaks[finished_login] = nil
  end
  previous_logins = logins
  start_date = start_date + increment
end

streaks = streaks.sort_by{ |streak| streak[:days] }.reverse

def print_streaks(streaks)
  col_size = 20
  puts %w(user days start end).map{|h| h.to_s.upcase.ljust(col_size)}.join
  streaks.each do |streak|
    puts [
      streak[:login],
      streak[:days],
      streak[:start],
      streak[:stop] 
    ].map { |val|
      val.to_s.ljust(col_size)
    }.join
  end
end

if @opts.format == 'csv'
  cols = %w(login days start stop)
  puts cols.join(',')
  streaks.each do |streak|
    puts cols.map{|c| streak[c.to_sym]}.join(',')
  end
else
  puts
  puts "GAPS"
  puts
  if gaps.size == 0
    puts "None!"
  else
    puts gaps.join("\n")
    puts
    puts "That's #{gaps.size} since #{start_date}"
  end
  puts
  puts "TOP 10 STREAKS SINCE #{start_date}"
  puts
  print_streaks(streaks[0..10])
  puts
  puts "TOP 10 STREAKS IN PROGRESS"
  puts
  print_streaks(streaks.select{|streak| (streak[:start]..streak[:stop]).cover?(Date.today)}[0..10])
  puts
end

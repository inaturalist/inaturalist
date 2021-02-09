# Subommand script example based on https://github.com/ManageIQ/optimist/wiki/Commands
require "optimist"

class GitStyle
  COMMAND_MAP = {
    "populate" => "Populates the frequency database tables",
    "export" => "Export a CSV of frequency data",
    "taxa" => "Export a CSV of taxa represented in the frequency data"
  }
  def initialize
    @subopts, @command = nil, nil
    @mainopts = Optimist::options do
      banner <<-EOT
Tools for managing the Rails side of denormalized observation frequency data.

Usage:
  rails r tools/frequency.rb [options] <command> [suboptions]

Examples:
  rails r tools/frequency.rb populate
  rails r tools/frequency.rb export -f path/to/freq.csv
  rails r tools/frequency.rb taxa -f path/to/taxa.csv

Options:
      EOT
      opt :help, "Show help message"          ## add this here or it goes to bottom of help
      stop_on COMMAND_MAP.keys
      banner "\nCommands:"
      COMMAND_MAP.each { |cmd, desc| banner format("  %-10s %s", cmd, desc) }
    end
    Optimist.educate if ARGV.empty?
    @command = ARGV.shift
    Optimist.die "unknown subcommand #{@command.inspect}" unless COMMAND_MAP.key? @command
    self.send("opt_#{@command}")  ## dispatch to command handling method
  end
  
  def opt_populate
    cmd = @command
    FrequencyCell.populate
  end

  def opt_export
    cmd = @command
    @subopts = Optimist::options do
      banner "options for #{cmd}"
      opt :path, "Path to export file", type: :string, short: "-f", required: true
    end
    FrequencyCell.export( File.expand_path( @subopts.path ) )
    puts "Wrote frequencies to #{@subopts.path}"
  end

  def opt_taxa
    cmd = @command
    @subopts = Optimist::options do
      banner "options for #{cmd}"
      opt :path, "Path to export file", type: :string, short: "-f", required: true
    end
    FrequencyCell.export_taxa( File.expand_path( @subopts.path ) )
    puts "Wrote taxa to #{@subopts.path}"
  end

  attr_reader :mainopts, :command, :subopts
end

optdb = GitStyle.new( )

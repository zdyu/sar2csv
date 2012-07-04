
# sar2csv.rb - convert SAR data to CSV format.
#
# 12/9/2010: fixed a bug when there is only 1 device for per_device_counters
# 9/21/2010: initial version.
#

require 'getoptlong'

PER_DEVICE_COUNTERS=["CPU", "INTR", "TTY", "DEV", "IFACE"]

def usage
message= <<HELP

 usage: sar2csv.rb -i <input_file> -o <output_file> [options]

  options:
    -i, --input               input file
    -o, --output              output file
    -t, --type                output format, could be 'csv' or 'tsv'

  examples:
    emon2csv -i sar.dat -o sar.csv
    emon2csv -i sar.dat -o sar.tsv -t tsv

HELP
  puts message
  exit 0
end

class Sample < Hash
  def timestamp
    return self["timestamp"]
  end
  
  def Sample.parse(block)
    matrix = Array.new
	  block.each_index do |index|
	    matrix[index] = block[index].split(" ")
	  end

    sample = Sample.new
    if matrix.size >2 || (matrix.size==2 && PER_DEVICE_COUNTERS.include?(matrix[0][1]))
      counters = matrix[0]
	    (1..matrix.size-1).each do |row_index|
	      (2..counters.size-1).each do |col_index|
		      sample[matrix[0][1] + "_" + matrix[row_index][1] + "_" + matrix[0][col_index]] = matrix[row_index][col_index]
		    end
	    end
	    sample["timestamp"] = matrix[1][0]
    elsif matrix.size == 2
      counters = matrix[0]
	    values = matrix[1]
  	  counters.each_index do |index|
	      if index == 0
  		    sample["timestamp"] = values[0]
	  	  else
		      sample[counters[index]] = values[index]
		    end
	    end
    end
	  return sample
  end
end

$input_file = nil
$output_file = nil
$delimiter = ","

def parse_options
  options = GetoptLong.new( [ '--help',     '-h', GetoptLong::NO_ARGUMENT ],
                            [ '--input',    '-i', GetoptLong::REQUIRED_ARGUMENT ],
                            [ '--output',   '-o', GetoptLong::REQUIRED_ARGUMENT ],
                            [ '--type',     '-t', GetoptLong::REQUIRED_ARGUMENT ] )
  begin
    usage if (ARGV.length == 0)
    options.each do | option, argument |
      case option
      when "--help"
        usage
      when "--input"
        $input_file = argument
        usage unless File.file?( $input_file )
      when "--output"
        $output_file = argument
      when "--type"
        case argument.downcase
        when "csv"
          $delimiter = ","
        when "tsv"
          $delimiter = "\t"
        else
          puts "\n incorrect -t parameter specified.\n"
          exit 1
        end
      else
        usage
      end
    end
    usage if $input_file.nil? || $output_file.nil?
  rescue
    usage
  end
end

def main
  parse_options

  samples = Array.new
  lines = 0
  start_time = Time.now
  
  block = Array.new
  sample = Sample.new
  puts " reading input file..."
  all_lines = File.readlines($input_file)
  all_lines.each do |line|
    case line
    when /^\s*$/
      partial = Sample.parse(block)
	    if sample.timestamp.nil? || sample.timestamp == partial.timestamp
	      sample.merge!(partial)
	    else
	      samples << sample
	      sample = Sample.new
	      sample.merge!(partial)
	    end
	    block = Array.new
    when /^(\d\d:\d\d:\d\d)( PM| AM)?\s+(.*)/
      block << line.gsub(" AM", "AM").gsub(" PM", "PM")
    end
    lines += 1
    if lines % 100000 == 0
      puts " #{lines} lines processed (#{lines*100/all_lines.size}%)."
    end
  end
  puts " #{lines} lines processed (100%)."

  puts " #{samples.size} samples parsed in #{Time.now-start_time} seconds."
  if samples.size > 0
    puts " writing output file..."
    output = File.open( $output_file, "w" )
    keys = samples[0].keys.sort
    keys.each_with_index do |key,index|
      output.print key
      if index < keys.size - 1
        output.print $delimiter
      end
    end
    output.print "\n"
    samples.each do |sample|
      keys.each_with_index do |key,index|
        output.print sample[key]
        output.print $delimiter if index < keys.size - 1
      end
      output.print "\n"
    end
    output.close
  end
end

main

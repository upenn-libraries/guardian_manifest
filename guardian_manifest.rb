#!/usr/bin/env ruby

require 'csv'
require 'yaml'
require 'json'
require 'securerandom'

require 'pry'

DEFAULT_HEADERS = %w[todo_base id source workspace compressed_destination verification_destination cleanup_directories glacier_description glacier_vault application method verify_compressed_archive]

FIELD_SEPARATOR = '|'

SAMPLE_PROPORTION_REGEX = %r{\A(\d+)\s*/\s*(\d+)\z}

REQUIRED_VALUES = %w[source workspace compressed_destination compressed_extension description_values vault application method directive_names]

def missing_args?
  return ARGV[0].nil?
end

##
# Based on +method+ construct the proper source path or URI for the object.
#
# == Examples
#
#    build_source('gitannex', 'share/path', 'mscodex123')
#    # => '/share/path/mscodex123.git'
#
#    build_source('rysnc', 'rsync://openn.library.upenn.edu/OPenn/Data/0020/Data/WaltersManuscripts', 'W681')
#    # => 'rsync://openn.library.upenn.edu/OPenn/Data/0020/Data/WaltersManuscripts/W681s'
#
# @param [String] method the retrieval method; e.g., +gitannex+, +rsync+
# @param [String] source base path/URI for the object
# @param [String] dirname name of the object to retrieve
# @return [String] full path/URI for the object
def build_source(method, source, dirname)
  case method
  when 'gitannex'
    "#{source}/#{dirname}.git"
  when 'rsync'
    "#{source}/#{dirname}"
  else
    raise "Unknown source_type: '#{method}' (expected: 'gitannex' or 'rsync')"
  end
end

##
# Generate the object-specific workspace directory
#
# For example:
#
#    /workspace/W681-7e4c11d3-5f33-4265-b44a-7d3501424ca0
#
# @param [String] root_dir guardian path for workspace
# @param [String] dirname object/todo_base name
# @param [String] uuid
# @return [String] absolute path to the object-specific workspace directory
def build_workspace_dir(root_dir, dirname, uuid)
  "/#{root_dir}/#{dirname}-#{uuid}"
end

##
# Generate the object-specific archive path
#
# For example:
#
#    /zip_workspace/W681-7e4c11d3-5f33-4265-b44a-7d3501424ca0/W681.zip
#
# @param [String] root_dir guardian path for zip workspace
# @param [String] dirname object/todo_base name
# @param [String] uuid
# @param [String] extension compressed archive extension without preceding period; e.g., +zip+
# @return [String] absolute path to the object-specific compressed archive
def build_compressed_dest(root_dir, dirname, uuid, extension)
  "/#{root_dir}/#{dirname}-#{uuid}/#{dirname}.#{extension}"
end

##
# Generate the object-specific verification directory
#
# For example:
#
#    /verification_workspace/W681-7e4c11d3-5f33-4265-b44a-7d3501424ca0
#
# @param [String] root_dir guardian path for verification workspace
# @param [String] dirname object/todo_base name
# @param [String] uuid
# @return [String] absolute path to the object-specific verification workspace directory
def build_verification_dir(root_dir, dirname, uuid)
  return unless root_dir
  "/#{root_dir}/#{dirname}-#{uuid}"
end

##
# Based on +verification_sample_size+, select a subset of +directives+ for which
# to perform post-compression verification of contents.
#
# The +verification_sample_size+ value can be one of three things:
#
# +ALL+:: returns a new array of all the directive names (not case-sensitive)
#
# Blank:: +nil+ or +''+ (empty string); returns an empty array +[]+
#
# A proportion:: a string value like '7/10', '53 / 100'; returns a new array of
#               a random selection in the specified proportion
#
# Note: Proportion is applied to the total size of +directives+. If the
# proportion is '7 / 10' and there are 20 directives, an array of 14 directives
# selected at random will be returned. If there are 8 directives, a sample set
# of 6 will be returned, and so on.
#
# @param [String] verification_sample_size 'ALL', a proportion (like, '2/3'),
#                 or blank ('' or +nil+) for an empty sample set
# @param [Array<String>] directives the list of all +:directive_names+ from
#                        the YAML inventory
# @return [Array<String>] the list of directive names for verification or +[]+
# @raise [ArgumentError] if +verification_sample_size+ cannot be interpreted
def build_sample_set(verification_sample_size, directives)
  return [] if verification_sample_size.to_s.strip.empty?
  return directives.dup.freeze if verification_sample_size.to_s.strip.downcase == 'all'

  if verification_sample_size.to_s.strip =~ SAMPLE_PROPORTION_REGEX
    # if verification_sample_size is 7/10, return an array of 7 random numbers
    # from 0-9
    numerator = $1.to_i
    denominator = $2.to_i
    count = directives.size
    sample_size = (Float(numerator)/denominator * count).round(0)
    indices = (0...count).to_a.sample(sample_size)
    return indices.map { |i| directives[i] }
  end

  raise ArgumentError, "Invalid verification_sample_size: #{verification_sample_size} (expected 'ALL' or a proportion, like '1/10')"
end

##
# Return +true+ if +sample_size+ is valid value: +nil+, a blank value (like
# +''+), +'ALL'+ (case insensitive), or a proportion expressed as a fraction
# (e.g., '52/100', '7 / 10').
#
# @param [String] sample_size the +verification_sample_size+ from the YAML
# @return [Boolean]
def valid_sample_size?(sample_size=nil)
  return true if sample_size.nil?
  normalized = sample_size.to_s.strip.downcase
  return true if normalized.empty?
  return true if normalized == 'all'
  return true if normalized =~ SAMPLE_PROPORTION_REGEX

  return false
end

##
# Check YAML data for required and valid values.
#
# @param [Hash] yaml_data parsed YAML data
# @raise [RuntimeError] if any errors are encountered
def validate_yaml(yaml_data)
  missing = REQUIRED_VALUES.select { |head| yaml_data[head].to_s.strip.empty? }
  raise "Required YAML values missing: #{missing.join(', ')}" unless missing.empty?

  # if no `verification_sample_size` is given, we're done
  return if yaml_data['verification_sample_size'].to_s.strip.empty?

  unless valid_sample_size?(yaml_data['verification_sample_size'])
    raise "Invalid verification_sample_size: '#{yaml_data['verification_sample_size']}' (expected 'ALL' or a proportion, like '1/10')"
  end

  if yaml_data['verification_destination'].to_s.strip.empty?
    raise "'verification_destination' must be provided if 'verification_sample_size' is set"
  end
end

def parse_inventory(yml)
  inventory = []
  yaml = YAML.load_file(yml)
  validate_yaml(yaml)
  sample_set = build_sample_set(yaml['verification_sample_size'], yaml['directive_names'])
  yaml['directive_names'].each do |dirname|
    uuid = SecureRandom.uuid
    workspace_dir = build_workspace_dir(yaml['workspace'], dirname, uuid)
    compressed_dest = build_compressed_dest(yaml['compressed_destination'], dirname, uuid, yaml['compressed_extension'])
    verification_dir = build_verification_dir(yaml['verification_destination'], dirname, uuid)
    dir_entry = {}
    dir_entry['todo_base'] = dirname
    dir_entry['id'] = dir_entry['todo_base']
    yaml['description_values']['description'] = dirname
    dir_entry['source'] = build_source(yaml['method'], yaml['source'], dirname)
    dir_entry['workspace'] = workspace_dir
    dir_entry['compressed_destination'] = compressed_dest
    dir_entry['cleanup_directories'] = [ workspace_dir, File.dirname(compressed_dest), verification_dir ].uniq.compact.join(FIELD_SEPARATOR)
    dir_entry['glacier_description'] = yaml['description_values'].to_json
    dir_entry['glacier_vault'] = yaml['vault']
    dir_entry['application'] = yaml['application']
    dir_entry['method'] = yaml['method']
    # if there's not a verification destination, don't set any verification values
    unless verification_dir.nil?
      dir_entry['verification_destination'] = verification_dir
      dir_entry['verify_compressed_archive'] = sample_set.include?(dirname)
    end
    inventory << dir_entry
  end
  return inventory
end

abort('Specify a path to a YAML manifest') if missing_args?
manifest_inventory = ARGV[0]
file_name = ARGV[1].nil? ? 'guardian_manifest.csv' : "#{File.basename(ARGV[1], '.*')}.csv"
inventory = parse_inventory(manifest_inventory)

# Determine the headers present in the inventory YAML
actual_headers = DEFAULT_HEADERS.dup
# check for optional columns
actual_headers.delete('verification_destination') unless inventory.first['verification_destination']
actual_headers.delete('verify_compressed_archive') unless inventory.first['verification_destination']

CSV.open(file_name, "wb", :headers => true) do |manifest|
  manifest << actual_headers
  inventory.each do |entry|
    manifest << entry
  end
end

puts "CSV written to #{file_name}."

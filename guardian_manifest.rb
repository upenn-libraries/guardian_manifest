#!/usr/bin/env ruby

require 'csv'
require 'yaml'

require 'pry'

HEADERS = %w[todo_base source workspace compressed_destination glacier_description glacier_vault application method]

def missing_args?
  return ARGV[0].nil?
end

def parse_inventory(yml)
  inventory = []
  yaml = YAML.load_file(yml)
  yaml['directive_names'].each do |dirname|
    dir_entry = {}
    dir_entry['todo_base'] = dirname
    yaml['description_values']['description'] = dirname
    dir_entry['source'] = "/#{yaml['source']}/#{dirname}.git"
    dir_entry['workspace'] = "/#{yaml['workspace']}"
    dir_entry['compressed_destination'] = "#{yaml['compressed_destination']}/#{dirname}.#{yaml['compressed_extension']}"
    dir_entry['glacier_description'] = yaml['description_values'].to_s
    dir_entry['glacier_vault'] = yaml['vault']
    dir_entry['application'] = yaml['application']
    dir_entry['method'] = yaml['method']
    inventory << dir_entry
  end
  return inventory
end

abort('Specify a path to a YAML manifest') if missing_args?
manifest_inventory = ARGV[0]
file_name = ARGV[1].nil? ? 'guardian_manifest.csv' : "#{File.basename(ARGV[1], '.*')}.csv"
inventory = parse_inventory(manifest_inventory)

CSV.open(file_name, "wb") do |manifest|
  manifest << HEADERS
  inventory.each do |line|
    line_entry = []
    line.each do |key, value|
      line_entry << value
    end
    manifest << line_entry
  end
end

puts "CSV written to #{file_name}."
#!/usr/bin/env ruby

require 'rubyXL'
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

def set_headers(worksheet)
  HEADERS.each_with_index do |header, index|
    worksheet.add_cell(0,index, header)
  end
end

workbook = RubyXL::Workbook.new

def workbook.worksheet
  return worksheets[0]
end

def workbook.set_up_spreadsheet
  worksheet.sheet_name = 'descriptive'
  set_headers(worksheet)
end

def workbook.populate(inventory)
  inventory.each_with_index do |row, y_index|
    HEADERS.each_with_index do  |header, x|
      worksheet.add_cell(y_index+1, x, row[header]) unless row[header].nil?
    end
  end
end

abort('Specify a path to a text manifest') if missing_args?
manifest_inventory = ARGV[0]
spreadsheet_name = ARGV[1].nil? ? 'guardian_manifest.xlsx' : "#{File.basename(ARGV[1], '.*')}.xlsx"
workbook.set_up_spreadsheet
inventory = parse_inventory(manifest_inventory)
workbook.populate(inventory)
workbook.write(spreadsheet_name)
puts "Spreadsheet written to #{spreadsheet_name}."
#!/usr/bin/env ruby

require 'rubyXL'

HEADERS = %w[todo_base source workspace compressed_destination glacier_description glacier_vault application method]

def missing_args?
  return ARGV[0].nil?
end

def parse_manifest(manifest)
  inventory = []
  manifest_lines = File.readlines(manifest)
  manifest_lines.shift
  manifest_lines.each do |line|
    line_entries = {}
    line.chomp!
    values = line.split('|')
    values.each_with_index do |value, position|
      line_entries[HEADERS[position]] = value
    end
    inventory << line_entries
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
inventory = parse_manifest(manifest_inventory)
workbook.populate(inventory)
workbook.write(spreadsheet_name)
puts "Spreadsheet written to #{spreadsheet_name}."
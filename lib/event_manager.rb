# frozen_string_literal:true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

puts 'Event Manager Initialized!'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_number(number)
  number.delete!(number.scan(/\D/).join)
  return number[1..9] if number.length == 11 && number[0] == '1'
  return 'Invalid phone number' if number.length > 10 || number.length < 10

  number
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue Google::Apis::ClientError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exists?('output')
  filename = "output/thanks_#{id}.html"
  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def show_registrations_by_hour(reg_hour_tally)
  puts 'Hour | Number of registrations'
  reg_hour_tally.tally.sort_by { |_key, value| -value}.to_h.each do |key, value|
    puts "#{key} | #{value}"
  end
end

def show_registrations_by_weekday(reg_day_tally)
  puts 'Weekday | Number of registrations'
  reg_day_tally.tally.sort_by { |key, value| -value}.to_h.each do |key, value|
    puts "#{Date::DAYNAMES[key]} | #{value}"
  end
end

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

reg_hour_tally = []
reg_day_tally = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_number(row[:homephone])
  reg_time = Time.strptime(row[:regdate], '%m/%d/%y %k:%M')
  reg_hour_tally << reg_time.hour
  reg_day_tally << reg_time.wday
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
  puts "#{name} #{phone_number} #{reg_time}"
end

show_registrations_by_hour(reg_hour_tally)
show_registrations_by_weekday(reg_day_tally)

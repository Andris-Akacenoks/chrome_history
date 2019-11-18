require 'sqlite3'
require 'date'
require 'json'

USER = 'andrisakacenko'
CHROME_HISTORY_PATH = "/Users/#{USER}/Library/Application\\ Support/Google/Chrome/Profile\\ 3"
DB_PATH = "/Users/andrisakacenko/Library/Application\ Support/Google/Chrome/Profile\ 3/History.db"

toxic_domains = {
	'facebook.com' => 0,
	'youtube.com' => 0,
	'reddit.com' => 0,
	'delfi.lv' => 0,
	'db.lv' => 0,
	'tvnet.lv' => 0,
	'instagram.com' => 0
}

def prepare_db
	command = "cp #{CHROME_HISTORY_PATH}/History " \
 						"#{CHROME_HISTORY_PATH}/History.db"
	`#{command}`
end	

def read_history(db_file)
	begin
		morning = (Time.now - (3600 * 24)).strftime("%Y-%m-%d") # yesterday
		db = SQLite3::Database.open(db_file)
		querry = "SELECT * FROM urls " \
						 "WHERE datetime(last_visit_time / 1000000 + (strftime('%s', '1601-01-01')), 'unixepoch') > '#{morning}' " \
						 "ORDER BY last_visit_time ASC "

		statement = db.prepare(querry)
		results = statement.execute

		history = []
		results.each do |row| 	
			history << parse_row(row)
		end
		return history
	rescue SQLite3::Exception => e 
		puts "Exception occurred: #{e}"
	ensure
		statement.close if statement
		db.close if db
	end
	nil
end

def parse_row(row)
	{
		:id => row[0],
		:url => row[1],
		:title => row[2],
		:visit_count => row[3],
		:typed_count => row[4],
		:last_visit_time => prettify_chrome_ts(row[5]),
		:hidden => row[6]
	}
end

def prettify_chrome_ts(chrome_ts)
	chrome_timestamp = chrome_ts.to_i
	since_epoch = DateTime.new(1601,1,1).to_time.to_i
	final_epoch = (chrome_timestamp / 1000000) + since_epoch
	DateTime.strptime(final_epoch.to_s, '%s')
end

def get_domains(history)
	domains = []
	history.each do |entry|
		url = entry[:url].match('^(?:http:\/\/|www\.|https:\/\/)([^\/]+)').to_s
		domain = url.gsub('http://', '').gsub('https://', '').gsub('www.', '')
		domains << domain
	end
	domains
end

def get_toxic_usage(total, toxic_domains)
	total.each do |domain|
		toxic_domains[domain] += 1 if toxic_domains.include?(domain)
	end
	toxic_domains
end

# Rename History to History.db to read here
prepare_db
                   
# Get all history data
history_hash = read_history(DB_PATH)
                   
# Get only domain names
all_domains = get_domains(history_hash)
                   
# Find how much of each toxic site were visited
toxic_summary = get_toxic_usage(all_domains, toxic_domains)
puts JSON.pretty_generate(toxic_summary)

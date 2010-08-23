# Stolen from http://snippets.dzone.com/posts/show/3714
# gem uninstall sqlite3
# gem install sqlite3-ruby

require 'rubygems'
require 'active_record'
require 'simple-rss'       # to install
require 'open-uri'
require 'twitter'          # to install
require 'pp'
require 'yaml'

def short(url)
  open('http://tinyurl.com/api-create.php?url=' + url).read.to_s
end

# Load the Configuration Settings

config = ARGV[0]
config = "demo" if config.nil?
configuration = File.open("#{config}.yaml") { |file| YAML.load(file) }

scriptname = configuration[:profile]
feeds = configuration[:feeds]
credentials = configuration[:credentials]

#twitter account to post to
twitter_email = credentials[:user]
twitter_password = credentials[:password]

httpauth = Twitter::HTTPAuth.new(twitter_email, twitter_password)

rss_user_agent = "http://officinadeiblog.com/bot"

#sqlite db
path_to_sqlite_db = "./#{scriptname}.sqlite"

# ActiveRecord::Base.logger = Logger.new(STDERR)
# ActiveRecord::Base.colorize_logging = true

ActiveRecord::Base.establish_connection(
    :adapter => "sqlite3",
    :dbfile  => path_to_sqlite_db
)

begin
  ActiveRecord::Schema.define do
      create_table :items do |table|
          table.column :feedname, :string
          table.column :title, :string
          table.column :link, :string
      end
  end
rescue
  puts "Database is there..."
end

twitter = Twitter::Base.new(httpauth)

class Item < ActiveRecord::Base
  def to_s
    slink = short(self.link)
    txtlength = 130-(slink.length + self.feedname.length)
    txt = self.title[0..txtlength]
    "[#{self.feedname}] #{txt} #{slink}"
  end
end

#run the beast

feeds.each do |feed_name, rss_url|
  # Fetch the RSS
  rss_items = SimpleRSS.parse open(rss_url ,"User-Agent" => rss_user_agent)
  # Process the single line
  for item in rss_items.items
    Item.transaction do
      unless existing_item = Item.find(:all, :conditions => ["link=?", item.link]).first
        new_item = Item.create(:feedname => feed_name, :title => item.title, :link => item.link) 
        puts "Publishing: #{new_item.to_s}"
        twitter.update(new_item.to_s)
      else
        puts "\tSkip: [#{feed_name}] #{item.title}"
      end
    end
  end
end

__END__

# FEEDS
feeds = {}
feeds["Blog"] = "http://www.lastknight.com/feed"
feeds["Links"] = "http://www.google.com/reader/public/atom/user%2F09538125876137983874%2Fstate%2Fcom.google%2Fbroadcast"
feeds["Flickr"] = "http://api.flickr.com/services/feeds/photos_public.gne?id=32162872@N00&lang=en-us&format=rss_200"

hstore = {}
hstore[:profile] = scriptname
hstore[:credentials] = {:user => twitter_email, :password => twitter_password}
hstore[:feeds] = feeds
File.open("#{scriptname}.yaml", "w") { |file| YAML.dump(hstore, file) }




# frozen_string_literal: true

# Dependencies:
require 'bundler/setup'
require 'nokogiri'
require 'net/http'
require 'uri'
require 'fileutils'

# Where are we hosting this?
DOMAIN = 'bbc-feeds.danq.dev'

# Editions of BBC News that we improve:
EDITIONS = {
  'full'     => 'https://feeds.bbci.co.uk/news/rss.xml',
  'uk'       => 'https://feeds.bbci.co.uk/news/uk/rss.xml',
  'world'    => 'https://feeds.bbci.co.uk/news/world/rss.xml',
  'business' => 'https://feeds.bbci.co.uk/news/business/rss.xml',
  'politics' => 'https://feeds.bbci.co.uk/news/politics/rss.xml',
  'africa'   => 'https://feeds.bbci.co.uk/news/world/africa/rss.xml',
  'india'    => 'https://feeds.bbci.co.uk/news/world/asia/india/rss.xml'
}.freeze

# Kinds of improvements:
VERSIONS = {
  'sports': {
    reject_guids: %r{^https://www\.bbc\.(co\.uk|com)/(iplayer|sounds|ideas|news/videos|programmes)/},
    reject_titles: /^(BBC News app)$/
  },

  'no-sports': {
    reject_guids: %r{^https://www\.bbc\.(co\.uk|com)/(sport|iplayer|sounds|ideas|news/videos|programmes)/},
    reject_titles: /^(BBC News app)$/
  }
}.freeze

# Create an output directory:
FileUtils.mkdir_p('build')

# Make a list of HTML links as we go:
html = ''

# For each edition/version permutation, fetch, filter, and output the feed:
EDITIONS.each do |edition, url|
  content = Net::HTTP.get(URI.parse(url))
  feed = Nokogiri::XML(content)

  VERSIONS.each do |version, filters|
    rss = feed.dup
    output = "#{edition}-#{version}.xml"

    # Comment-out items that match our rejection criteria for this version:
    rss.css('item').select { |item| item.css('guid').text =~ filters[:reject_guids] || item.css('title').text =~ filters[:reject_titles] }.each do |item|
      item.swap("<!-- [REJECTED] #{item.to_s.gsub(/--/, '[hyphen][hyphen]')} -->")
    end

    # Strip anchors off <guid>s: BBC News "republishes" with #0, #1, #2... which results in duplicates in readers:
    rss.css('guid').each { |g| g.content = g.content.gsub(/#.*$/, '') }

    # Now there might be duplicate <guid>s, which is usually harmless but isn't pretty (and violates the spec):
    rss.css('guid').map(&:text).each do |guid|
      matching_items = rss.css('item').select { |item| item.css('guid').text == guid }
      duplicate_items = matching_items[1..]
      duplicate_items.each { |item| item.swap("<!-- [DUPLICATE] #{item.to_s.gsub(/--/, '[hyphen][hyphen]')} -->") }
    end

    # Tag us as the generator
    generator = rss.css('generator')[0]
    generator.content = "Dan Q's 'BBC News without the crap' <https://danq.me/> <https://#{DOMAIN}/> generator"

    # Update the src to us:
    rss.xpath('//atom:link').attr('href', "https://#{DOMAIN}/#{output}")

    # Write the output
    File.open("build/#{output}", 'w') { |f| f.puts(rss.to_s) }

    # Add a link to the HTML
    html += "<li><a href=\"#{output}\">[RSS] #{edition}, #{version} edition</a></li>"
  end
end

# Load the template HTML file:
template = File.read('index.template.html')

# Create a HTML file describing the feeds:
File.open('build/index.html', 'w') do |f|
  f.puts template.gsub('{{FEEDS}}', html)
end

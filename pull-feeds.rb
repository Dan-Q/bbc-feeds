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
  'full'     => {
    url: 'https://feeds.bbci.co.uk/news/rss.xml',
    variants: %w{ sports no-sports }
  },
  'uk'       => {
    url: 'https://feeds.bbci.co.uk/news/uk/rss.xml',
    variants: %w{ sports no-sports },
    title: 'UK',
    icon: '🇬🇧'
  },
  'world'    => {
    url: 'https://feeds.bbci.co.uk/news/world/rss.xml',
    variants: %w{ sports no-sports },
    icon: '🌍'
  },
  'business' => {
    url: 'https://feeds.bbci.co.uk/news/business/rss.xml',
    variants: %w{ sports no-sports },
    icon: '💼'
  },
  'politics' => {
    url: 'https://feeds.bbci.co.uk/news/politics/rss.xml',
    variants: %w{ sports no-sports },
    icon: '🗳️'
  },
  'africa'   => {
    url: 'https://feeds.bbci.co.uk/news/world/africa/rss.xml',
    variants: %w{ sports no-sports }
  },
  'india'    => {
    url: 'https://feeds.bbci.co.uk/news/world/asia/india/rss.xml',
    variants: %w{ sports no-sports }
  },
  'scotland' => {
    url: 'https://feeds.bbci.co.uk/news/scotland/rss.xml',
    variants: %w{ sports no-sports },
    icon: '🏴󠁧󠁢󠁳󠁣󠁴󠁿'
  },
  'break-1' => false,
  'sport' => {
    url: 'https://feeds.bbci.co.uk/sport/rss.xml',
    variants: %w{ sports },
    title: 'Sports',
    icon: '🏏'
  },
  'sport-scotland' => {
    url: 'https://feeds.bbci.co.uk/sport/scotland/rss.xml',
    variants: %w{ sports },
    title: 'Sports Scotland',
    icon: '🏴󠁧󠁢󠁳󠁣󠁴󠁿'
  }
}.freeze

# Kinds of improvements:
VARIANT_DEFINITIONS = {
  'sports': {
    reject_guids: %r{^https://www\.bbc\.(co\.uk|com)/(iplayer|sounds|ideas|news/videos|programmes)/},
    reject_titles: /^(BBC News app)$/,
    description: '(⚽ includes sports)'
  },

  'no-sports': {
    reject_guids: %r{^https://www\.bbc\.(co\.uk|com)/(sport|iplayer|sounds|ideas|news/videos|programmes)/},
    reject_titles: /^(BBC News app)$/,
    description: '(❌ no sports)'
  },
}.freeze

# Create an output directory:
FileUtils.mkdir_p('build')

# An RSS icon to insert
RSS_ICON = '<svg aria-label="RSS feed " viewBox="0 0 512 512"><rect width="512" height="512" fill="#f80" rx="15%"/><circle cx="145" cy="367" r="35" fill="#fff"/><path fill="none" stroke="#fff" stroke-width="60" d="M109 241c89 0 162 73 162 162m114 0c0-152-124-276-276-276"/></svg>'

# Make a list of HTML links as we go:
html = ''

# For each edition/version permutation, fetch, filter, and output the feed:
EDITIONS.each do |edition, definition|
  if ! definition
    # editions with no definition are breaks in the list
    html += '</ul><ul>'
    next
  end

  content = Net::HTTP.get(URI.parse(definition[:url]))
  feed = Nokogiri::XML(content)

  definition[:variants].each do |variant|
    raise "Unknown variant #{variant} for edition #{edition}" unless filters = VARIANT_DEFINITIONS[variant.to_sym]
    rss = feed.dup
    output = "#{edition}-#{variant}.xml"

    # Comment-out items that match our rejection criteria for this variant:
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
    html += <<~HTML.chomp
      <li>
        <a href="#{output}">
          #{RSS_ICON}#{definition[:icon] ? "#{definition[:icon]} " : ''}#{definition[:title] || edition.capitalize}
          #{definition[:variants].length > 1 ? filters[:description] : ''}
        </a>
      </li>
    HTML
  end
end

# Load the template HTML file:
template = File.read('index.template.html')

# Create a HTML file describing the feeds:
File.open('build/index.html', 'w') do |f|
  f.puts template.gsub('{{FEEDS}}', html)
end

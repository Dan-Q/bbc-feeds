#!/usr/bin/env ruby
# frozen_string_literal: true

# Dependencies:
require 'bundler/setup'
require 'nokogiri'
require 'net/http'
require 'uri'
require 'fileutils'
require 'yaml'

# Monkey-patch String with a edition_titleify (capitalise first letter, turn underscores into spaces) method:
class String
  def edition_titleify
    (self[0].upcase + self[1..]).gsub(/_/, ' ')
  end
end

# Verbose-by-default
VERBOSE = true

# Where are we hosting this?
DOMAIN = 'bbc-feeds.danq.dev'

# Editions of BBC News that we improve (see config/editions.yml). Editions with a
# value of `false` are breaks in the list of feeds:
EDITIONS = YAML.safe_load_file(File.join(__dir__, 'config', 'editions.yml')).transform_values do |definition|
  definition && definition.transform_keys(&:to_sym)
end.freeze

# Kinds of improvements (see config/variant-definitions.yml):
VARIANT_DEFINITIONS = YAML.safe_load_file(File.join(__dir__, 'config', 'variant-definitions.yml')).to_h do |variant, definition|
  definition = definition.transform_keys(&:to_sym)
  [variant.to_sym, definition.merge(
    reject_guids: Regexp.new(definition[:reject_guids]),
    reject_titles: Regexp.new(definition[:reject_titles])
  )]
end.freeze

# Create an output directory:
FileUtils.mkdir_p('build')

# An RSS icon to insert
RSS_ICON = '<svg aria-label="RSS feed " viewBox="0 0 512 512"><rect width="512" height="512" fill="#f80" rx="15%"/><circle cx="145" cy="367" r="35" fill="#fff"/><path fill="none" stroke="#fff" stroke-width="60" d="M109 241c89 0 162 73 162 162m114 0c0-152-124-276-276-276"/></svg>'

# Initial and preferred thumbnail resolution width
THUMB_INITIAL_WIDTH = 240
THUMB_TARGET_WIDTH = 1200

# Make a list of HTML links as we go:
html = ''

puts "Decrappifying BBC News..." if VERBOSE

# For each edition/version permutation, fetch, filter, and output the feed:
EDITIONS.each do |edition, definition|
  if ! definition
    # editions with no definition are breaks in the list
    puts '----' if VERBOSE
    html += '</ul><ul>'
    next
  end

  puts("📰 #{definition[:title] || edition.edition_titleify} edition (#{definition[:url]})") if VERBOSE

  content = Net::HTTP.get(URI.parse(definition[:url]))
  feed = Nokogiri::XML(content)

  definition[:variants].each do |variant|
    raise "Unknown variant #{variant} for edition #{edition}" unless filters = VARIANT_DEFINITIONS[variant.to_sym]
    rss = feed.dup
    output = "#{edition}-#{variant}.xml"
    puts "  💾 build/#{output}" if VERBOSE

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

    # Enlarge the thumbnails of each item from 240x to 1200x
    rss.xpath('//media:thumbnail').each do |thumb|
      next unless thumb['url'] =~ /^https:\/\/ichef.bbci.co.uk\/ace\/(standard|ws)\/#{THUMB_INITIAL_WIDTH}\//
      thumb['url'] = thumb['url'].gsub(/\/ace\/(standard|ws)\/#{THUMB_INITIAL_WIDTH}\//, "/ace/\\1/#{THUMB_TARGET_WIDTH}/")
      thumb['width'] = THUMB_TARGET_WIDTH.to_s
      thumb['height'] = (thumb['height'].to_f / THUMB_INITIAL_WIDTH * THUMB_TARGET_WIDTH).round.to_s
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
          #{RSS_ICON}#{definition[:icon] ? "#{definition[:icon]} " : ''}#{definition[:title] || edition.edition_titleify}
          #{definition[:variants].length > 1 ? filters[:description] : ''}
        </a>
      </li>
    HTML
  end
end

# Tell GitHub Pages which domain name we're hosted on:
puts "💾 build/CNAME" if VERBOSE
File.write('build/CNAME', "#{DOMAIN}\n")

# Load the template HTML file:
template = File.read('index.template.html')

# Create a HTML file describing the feeds:
puts "💾 build/index.html" if VERBOSE
File.open('build/index.html', 'w') do |f|
  f.puts template.gsub('{{FEEDS}}', html)
end

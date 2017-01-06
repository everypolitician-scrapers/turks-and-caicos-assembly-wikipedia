#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
  constituency = ''
  noko.xpath('//h3[span[@id="By_constituency"]]/following-sibling::table[1]/tr[td]').each do |tr|
    tds = tr.css('td')
    constituency = tds.shift if tds.count == 4
    next if tds[0].css('b').empty?

    data = {
      name:     tds[0].text,
      wikiname: tds[0].xpath('.//a[not(@class="new")]/@title').text,
      party:    tds[1].text.tidy,
      area:     constituency.text.tidy.sub(/^\d+\.?\s+/, ''),
      term:     2012,
    }
    ScraperWiki.save_sqlite(%i(name term), data)
  end
end

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
scrape_list('https://en.wikipedia.org/wiki/Turks_and_Caicos_Islands_general_election,_2012')

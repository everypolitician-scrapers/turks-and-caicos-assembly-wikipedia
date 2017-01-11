#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'require_all'
require 'scraped'
require 'scraperwiki'

require_rel 'lib'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class ResultsPage < Scraped::HTML
  decorator UnspanAllTables

  field :winners do
    noko.xpath('//h3[span[@id="By_constituency"]]/following-sibling::table[1]/tr[td[.//b]]').map do |tr|
      fragment tr => WinnerRow
    end
  end
end

class WinnerRow < Scraped::HTML
  field :name do
    tds[1].text
  end

  field :wikiname do
    tds[1].xpath('.//a[not(@class="new")]/@title').text
  end

  field :party do
    tds[2].text.tidy
  end

  field :area do
    tds[0].at_xpath('./text()[1]').text.tidy.sub(/^\d+\.?\s+/, '')
  end

  private

  def tds
    noko.css('td')
  end
end

url = 'https://en.wikipedia.org/wiki/Turks_and_Caicos_Islands_general_election,_2012'
page = ResultsPage.new(response: Scraped::Request.new(url: url).response)
data = page.winners.map { |res| res.to_h.merge(term: 2012) }
# puts data

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(%i(name term), data)

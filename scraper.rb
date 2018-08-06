#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'require_all'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require_rel 'lib'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class ResultsPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links
  decorator UnspanAllTables

  field :winners do
    winner_rows.map { |tr| fragment tr => row_class }
  end

  private

  def winner_rows
    noko.xpath('//h3[span[@id="By_constituency"]]/following-sibling::table[1]/tr[td[.//b]]')
  end
end

class ResultsPage2012 < ResultsPage
  def row_class
    WinnerRow2012
  end
end

class ResultsPage2016 < ResultsPage
  def row_class
    WinnerRow2016
  end
end

class WinnerRow < Scraped::HTML
  field :name do
    tds[name_column].text.tidy
  end

  field :wikiname do
    tds[name_column].xpath('.//a[not(@class="new")]/@title').text
  end

  field :id do
    tds[name_column].css('a/@wikidata').map(&:text).first
  end

  field :party do
    tds[party_column].text.tidy
  end

  field :area do
    tds[area_column].at_xpath('./text()[1]').text.tidy.sub(/^\d+\.?\s+/, '')
  end

  private

  def tds
    noko.css('td')
  end

  def area_column
    colmap.find_index('area')
  end

  def name_column
    colmap.find_index('name')
  end

  def party_column
    colmap.find_index('party')
  end
end

class WinnerRow2016 < WinnerRow
  def colmap
    %w(areaid area name partycol party votes)
  end
end

class WinnerRow2012 < WinnerRow
  def colmap
    %w(area name party votes)
  end
end

def scrape(term, url)
  pageclass = Object.const_get("ResultsPage#{term}")
  page = pageclass.new(response: Scraped::Request.new(url: url).response)
  data = page.winners.map { |res| res.to_h.merge(term: term) }
  data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']
  ScraperWiki.save_sqlite(%i(name term), data)
end

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
scrape(2012, 'https://en.wikipedia.org/wiki/Turks_and_Caicos_Islands_general_election,_2012')
scrape(2016, 'https://en.wikipedia.org/wiki/Turks_and_Caicos_Islands_general_election,_2016')

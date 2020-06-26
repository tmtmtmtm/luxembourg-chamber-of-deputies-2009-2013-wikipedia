#!/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'pry'
require 'scraped'
require 'wikidata_ids_decorator'

require_relative 'lib/remove_notes'
require_relative 'lib/unspan_all_tables'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class LuxDate
  def initialize(str)
    @str = str
  end

  def to_date
    return unless str[/\d+.*\d{4}/]

    Date.parse english_str
  end

  private

  attr_reader :str

  # Yuck.
  def english_str
    str
      .gsub('Januar', 'January')
      .gsub('Februar', 'February')
      .gsub('Mäerz', 'March')
      .gsub('Abrëll', 'April')
      .gsub('Mee', 'May')
      .gsub('Juli', 'July')
      .gsub('Oktober', 'October')
  end
end

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links
  decorator UnspanAllTables
  decorator RemoveNotes

  # TODO: ex-members
  field :members do
    member_items.map { |li| fragment(li => MemberItem).to_h }
  end

  private

  def members_table
    noko.css('h3 #Period_2009-2013').xpath('./following::table')[0]
  end

  def member_items
    members_table.xpath('.//li')
  end
end

class MemberItem < Scraped::HTML
  field :id do
    person.attr('wikidata')
  end

  field :name do
    person.text
  end

  field :party do
    PARTIES.fetch(partyLabel)
  end

  field :partyLabel do
    noko.xpath('preceding::span[@class="mw-headline"]').last.text
  end

  field :start_date do
    LuxDate.new(from).to_date if from
  end

  private

  def person
    noko.css('a').first
  end

  # TODO: move this out to a file we can generate from SPARQL
  PARTIES = {
    'ADR' => 'Q339280',
    'CSV' => 'Q1344670',
    'onofhängeg' => 'Q327591',
    'DP' => 'Q1029792',
    'Déi Gréng' => 'Q767761',
    'Déi Lénk' => 'Q1270494',
    'LSAP' => 'Q1070311'
  }.freeze

  def from
    return if partyLabel == 'onofhängeg' # TODO: different format

    noko.text[/\(.*?(\d+.*20\d+).*?\)/, 1]
  end
end

url = 'https://lb.wikipedia.org/wiki/Chamber'
data = Scraped::Scraper.new(url => MembersPage).scraper.members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
puts header + rows.join

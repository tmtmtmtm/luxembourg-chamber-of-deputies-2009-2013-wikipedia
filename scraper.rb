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

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links
  decorator UnspanAllTables
  decorator RemoveNotes

  # TODO: ex-members
  field :members do
    member_rows.map { |tr| fragment(tr => MemberRow).to_h }
  end

  private

  def member_rows
    noko.xpath('//table[.//th[contains(.,"Circonscription")]]//tr[td]')
  end
end

class MemberRow < Scraped::HTML
  field :id do
    tds[1].xpath('.//a/@wikidata').text
  end

  field :name do
    tds[1].xpath('.//a').text
  end

  field :area do
    tds[2].xpath('.//a/@wikidata').text
  end

  field :areaLabel do
    tds[2].text.tidy
  end

  field :party do
    tds[4].xpath('.//a/@wikidata').text
  end

  field :partyLabel do
    tds[4].text.tidy
  end

  field :end_date do
    return unless tds[6]

    tds[6].css('time/@datetime').text
  end

  field :cause do
    return unless causeLabel

    CAUSE_LOOKUP.fetch(causeLabel)
  end

  field :causeLabel do
    return unless tds[5]

    tds[5].text.tidy
  end

  field :replaced_by do
    return unless tds[7]

    tds[7].xpath('.//a/@wikidata').map(&:text).first
  end

  private

  def tds
    noko.css('td')
  end

  CAUSE_LOOKUP = {
    'Démission' => 'Q796919',
    'Nomination dans le gouvernement' => 'Q51188211',
    'Mort en fonction' => 'Q5247364'
  }.freeze
end

url = 'https://fr.wikipedia.org/wiki/Liste_des_d%C3%A9put%C3%A9s_de_la_l%C3%A9gislature_2009-2013_de_la_Chambre_des_d%C3%A9put%C3%A9s_du_Luxembourg'
data = Scraped::Scraper.new(url => MembersPage).scraper.members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
puts header + rows.join

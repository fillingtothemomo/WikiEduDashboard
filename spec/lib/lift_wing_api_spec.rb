# frozen_string_literal: true

require 'rails_helper'
require_dependency "#{Rails.root}/lib/lift_wing_api.rb"

describe LiftWingApi do
  context 'when the wiki is not a wikipedia or wikidata' do
    before { stub_wiki_validation }

    let!(:wiki) { create(:wiki, project: 'wikivoyage', language: 'en') }
    let(:subject0) { described_class.new(wiki) }

    it 'raises an error' do
      expect { subject0 }.to raise_error LiftWingApi::InvalidProjectError
    end
  end

  describe '#get_revision_data' do
    let(:rev_ids) { [829840084, 829840085] }
    let(:deleted_rev_id) { 708326238 }
    let(:wiki) { create(:wiki, project: 'wikidata', language: nil) }

    let(:lift_wing_api_class_en_wiki) { described_class.new(Wiki.find(1)) }

    # Get revision data for valid rev ids for English Wikipedia
    let(:subject0) { lift_wing_api_class_en_wiki.get_revision_data(rev_ids) }

    # Get revision data for valid rev ids for Wikidata
    let(:subject1) { described_class.new(wiki).get_revision_data(rev_ids) }

    # Get revision data for deleted rev ids for English Wikipedia
    let(:subject2) { lift_wing_api_class_en_wiki.get_revision_data([deleted_rev_id]) }

    it 'fetches json from api.wikimedia.org for wikipedia' do
      VCR.use_cassette 'liftwing_api/wikipedia' do
        expect(subject0).to be_a(Hash)
        expect(subject0.dig('829840084', 'wp10').to_f).to eq(28.5936675221734978)
        expect(subject0.dig('829840084', 'features')).to be_a(Hash)
        expect(subject0.dig('829840084', 'deleted')).to eq(false)
        expect(subject0.dig('829840084', 'prediction')).to eq('Stub')

        expect(subject0).to be_a(Hash)
        expect(subject0.dig('829840085', 'wp10').to_f).to eq(29.15228958136511656)
        expect(subject0.dig('829840085', 'features')).to be_a(Hash)
        expect(subject0.dig('829840085', 'deleted')).to eq(false)
        expect(subject0.dig('829840085', 'prediction')).to eq('Start')
      end
    end

    it 'fetches json from api.wikimedia.org for wikidata' do
      VCR.use_cassette 'liftwing_api/wikidata' do
        expect(subject1).to be_a(Hash)
        expect(subject1.dig('829840084', 'wp10')).to eq(nil)
        expect(subject1.dig('829840084', 'features')).to be_a(Hash)
        expect(subject1.dig('829840084', 'deleted')).to eq(false)
        expect(subject1.dig('829840084', 'prediction')).to eq('D')

        expect(subject1.dig('829840085', 'wp10')).to eq(nil)
        expect(subject1.dig('829840085', 'features')).to be_a(Hash)
        expect(subject1.dig('829840085', 'deleted')).to eq(false)
        expect(subject1.dig('829840085', 'prediction')).to eq('D')
      end
    end

    it 'returns deleted equal to true if the revision was deleted' do
      VCR.use_cassette 'liftwing_api/deleted_revision' do
        expect(subject2).to be_a(Hash)
        expect(subject2.dig('708326238', 'wp10')).to eq(nil)
        expect(subject2.dig('708326238', 'features')).to eq(nil)
        expect(subject2.dig('708326238', 'deleted')).to eq(true)
        expect(subject2.dig('708326238', 'prediction')).to eq(nil)
      end
    end

    it 'handles timeout errors' do
      stub_request(:any, 'https://api.wikimedia.org')
        .to_raise(Errno::ETIMEDOUT)
      expect(lift_wing_api_class_en_wiki).to receive(:log_error).once
      expect(subject0.dig('829840085')).to be_a(Hash)
      expect(subject0.dig('829840085')).to be_empty
    end

    it 'handles connection refused errors' do
      stub_request(:any, 'https://api.wikimedia.org')
        .to_raise(Faraday::ConnectionFailed)
      expect(lift_wing_api_class_en_wiki).to receive(:log_error).once
      expect(subject0.dig('829840085')).to be_a(Hash)
      expect(subject0.dig('829840085')).to be_empty
    end

    it 'logs the error if something unexpected happens when building the successful response' do
      allow(lift_wing_api_class_en_wiki)
        .to receive(:build_successful_response)
        .and_raise(StandardError)
      expect(lift_wing_api_class_en_wiki).to receive(:log_error).once
      expect(subject0.dig('829840085')).to be_a(Hash)
      expect(subject0.dig('829840085')).to be_empty
    end
  end
end

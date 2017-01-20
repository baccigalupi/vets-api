# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::Forms::VA1990, type: :model, form: :education_benefits do
  let(:application) { FactoryGirl.create(:education_benefits_claim) }

  subject { described_class.new(application) }

  it 'has a 22-1990 type' do
    expect(described_class::TYPE).to eq('22-1990')
  end

  SAMPLE_APPLICATIONS = [
    :simple_ch33, :kitchen_sink
  ].freeze

  # For each sample application we have, format it and compare it against a 'known good'
  # copy of that submission. This technically covers all the helper logic found in the
  # `Form` specs, but are a good safety net for tracking how forms change over time.
  context '#text', run_at: '2016-10-06 03:00:00 EDT' do
    basepath = Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1990')
    SAMPLE_APPLICATIONS.each do |application_name|
      it "generates #{application_name} correctly" do
        json = File.read(File.join(basepath, "#{application_name}.json"))
        expect(json).to match_vets_schema('edu_benefits')
        test_application = EducationBenefitsClaim.new(form: json)
        result = described_class.new(test_application).text
        spl = File.read(File.join(basepath, "#{application_name}.spl"))
        expect(result).to eq(spl)
      end
    end
  end

  context '#rotc_scholarship_amounts' do
    it 'always outputs 5 double-spaced lines' do
      output = subject.rotc_scholarship_amounts(nil)
      expect(output.lines.count).to eq(9)
      (1..5).each do |i|
        expect(output).to include "Year #{i}"
      end
    end

    it 'includes partial records' do
      values = [OpenStruct.new(amount: 1), OpenStruct.new(amount: 2), OpenStruct.new(amount: 3)]
      output = subject.rotc_scholarship_amounts(values)
      expect(output.lines.count).to eq(9)
      (1..3).each do |i|
        expect(output).to include "Year #{i}"
        expect(output).to include "Amount: #{i}"
      end
      expect(output).to include 'Year 4'
      expect(output).to include 'Year 5'
    end
  end

  context '#disclosure_for' do
    before do
      subject.instance_variable_set(:@applicant, OpenStruct.new(benefitsRelinquishedDate: Time.zone.today))
    end
    { 'CH32': 'Chapter 32',
      'CH30': 'Chapter 30',
      'CH1606': 'Chapter 1606',
      'CH33': 'Chapter 33 - Not Eligible for Other Listed Benefits',
      'CH33_1606': "Chapter 33 in Lieu of Chapter 1606 - Effective: #{Time.zone.today}",
      'CH33_1607': "Chapter 33 in Lieu of Chapter 1607 - Effective: #{Time.zone.today}",
      'CH33_30': "Chapter 33 in Lieu of Chapter 30 - Effective: #{Time.zone.today}" }.each do |type, check|
      it "shows a partial containing the #{type} disclaimer" do
        output = subject.disclosure_for(type)
        expect(output).to include(check)
      end
    end
  end

  context '#disclosures' do
    it 'adds disclosures for different types' do
      expect(subject).to receive(:disclosure_for).with('CH30')
      expect(subject).to receive(:disclosure_for).with('CH32')
      expect(subject).to receive(:disclosure_for).with('CH33')
      expect(subject).to receive(:disclosure_for).with('CH1606')
      subject.disclosures(OpenStruct.new(chapter1606: true, chapter30: true, chapter32: true, chapter33: true))
    end

    it 'handles chapter 33 relinquishments' do
      expect(subject).to receive(:disclosure_for).with('CH33_1606')
      subject.disclosures(OpenStruct.new(chapter33: true, benefitsRelinquished: 'chapter1606'))
    end
  end
end
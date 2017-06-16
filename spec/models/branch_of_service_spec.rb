# frozen_string_literal: true
require 'rails_helper'

RSpec.describe BranchesOfService do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) do
      {
        begin_date: '1926-07-02T00:00:00-04:00',
        code: 'AC',
        end_date: '1941-06-20T00:00:00-04:00',
        flat_full_descr: 'US ARMY AIR CORPS',
        full_descr: 'US ARMY AIR CORPS',
        short_descr: 'USAAC',
        state_required: 'N',
        upright_full_descr: 'US ARMY AIR CORPS'
      }
    end

    let(:other) do
      described_class.new(
        begin_date: '1926-07-02T00:00:00-04:00',
        code: 'ZC',
        end_date: '1941-06-20T00:00:00-04:00',
        flat_full_descr: 'ZUS ARMY AIR CORPS',
        full_descr: 'ZUS ARMY AIR CORPS',
        short_descr: 'ZUSAAC',
        state_required: 'N',
        upright_full_descr: 'ZUS ARMY AIR CORPS'
      )
    end

    it 'populates attributes' do
      name_map = described_class.attribute_set.map(&:name)

      expect(name_map).to contain_exactly(
        :begin_date, :code, :end_date, :flat_full_descr, :full_descr, :short_descr, :state_required, :upright_full_descr
      )

      expect(subject.begin_date).to eq(Time.parse(params[:begin_date]).utc.strftime('%Y-%m-%d'))
      expect(subject.code).to eq(params[:code])
      expect(subject.end_date).to eq(Time.parse(params[:end_date]).utc.strftime('%Y-%m-%d'))
      expect(subject.flat_full_descr).to eq(params[:flat_full_descr])
      expect(subject.full_descr).to eq(params[:full_descr])
      expect(subject.short_descr).to eq(params[:short_descr])
      expect(subject.state_required).to eq(params[:state_required])
      expect(subject.upright_full_descr).to eq(params[:upright_full_descr])
    end

    it 'can be compared by full_descr' do
      expect(subject <=> other).to eq(-1)
      expect(other <=> subject).to eq(1)
    end
  end
end

# frozen_string_literal: true
require 'rails_helper'

RSpec.describe MhvAccount, type: :model do
  let(:mvi_profile) do
    build(:mvi_profile,
          icn: '1012667122V019349',
          given_names: %w(Hector),
          family_name: 'Allen',
          suffix: nil,
          gender: 'M',
          birth_date: '1932-02-05',
          ssn: '796126859',
          mhv_ids: mhv_ids,
          vha_facility_ids: vha_facility_ids,
          home_phone: nil,
          address: mvi_profile_address)
  end

  let(:mvi_profile_address) do
    build(:mvi_profile_address,
          street: '20140624',
          city: 'Houston',
          state: 'TX',
          country: 'USA',
          postal_code: '77040')
  end

  let(:user) do
    create(:loa3_user,
           ssn: mvi_profile.ssn,
           first_name: mvi_profile.given_names.first,
           last_name: mvi_profile.family_name,
           gender: mvi_profile.gender,
           birth_date: mvi_profile.birth_date,
           email: 'vets.gov.user+0@gmail.com')
  end

  let(:mhv_ids) { [] }
  let(:vha_facility_ids) { ['450'] }

  before(:each) do
    stub_mvi(mvi_profile)
  end

  it 'must have a user_uuid when initialized' do
    expect { described_class.new }
      .to raise_error(StandardError, 'You must use find_or_initialize_by(user_uuid: #)')
  end

  describe 'event' do
    context 'check_eligibility' do
      context 'with terms accepted' do
        let(:terms) { create(:terms_and_conditions, latest: true, name: described_class::TERMS_AND_CONDITIONS_NAME) }
        before(:each) { create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid) }

        let(:base_attributes) { { user_uuid: user.uuid, account_state: 'needs_terms_acceptance' } }

        context 'not a va patient' do
          let(:vha_facility_ids) { ['999'] }

          it 'is ineligible if not a va patient' do
            subject = described_class.new(base_attributes)
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('ineligible')
            expect(subject.eligible?).to be_falsey
            expect(subject.terms_and_conditions_accepted?).to be_truthy
          end
        end

        it 'is able to transition back to upgraded' do
          subject = described_class.new(base_attributes.merge(upgraded_at: Time.current))
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('upgraded')
          expect(subject.eligible?).to be_truthy
          expect(subject.terms_and_conditions_accepted?).to be_truthy
        end

        it 'is able to transition back to registered' do
          subject = described_class.new(base_attributes.merge(registered_at: Time.current))
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('registered')
          expect(subject.eligible?).to be_truthy
          expect(subject.terms_and_conditions_accepted?).to be_truthy
        end

        it 'it falls back to unknown' do
          subject = described_class.new(base_attributes)
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('unknown')
          expect(subject.eligible?).to be_truthy
          expect(subject.terms_and_conditions_accepted?).to be_truthy
        end
      end

      context 'with terms not accepted' do
        context 'not a va patient' do
          let(:vha_facility_ids) { ['999'] }

          it 'is ineligible if not a va patient' do
            subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
            subject.send(:setup) # This gets called when object is first loaded
            expect(subject.account_state).to eq('ineligible')
            expect(subject.eligible?).to be_falsey
            expect(subject.terms_and_conditions_accepted?).to be_falsey
          end
        end

        it 'transitions to needs_terms_acceptance' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'upgraded', upgraded_at: Time.current)
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('needs_terms_acceptance')
          expect(subject.eligible?).to be_truthy
          expect(subject.terms_and_conditions_accepted?).to be_falsey
        end

        it 'is able to transition back to registered' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'registered', registered_at: Time.current)
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('needs_terms_acceptance')
          expect(subject.eligible?).to be_truthy
          expect(subject.terms_and_conditions_accepted?).to be_falsey
        end

        it 'it falls back to unknown' do
          subject = described_class.new(user_uuid: user.uuid, account_state: 'unknown')
          subject.send(:setup) # This gets called when object is first loaded
          expect(subject.account_state).to eq('needs_terms_acceptance')
          expect(subject.eligible?).to be_truthy
          expect(subject.terms_and_conditions_accepted?).to be_falsey
        end
      end
    end
  end

  describe 'account creation and upgrade' do
    before(:each) do
      terms = create(:terms_and_conditions, latest: true, name: described_class::TERMS_AND_CONDITIONS_NAME)
      create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid)
    end

    subject { described_class.new(user_uuid: user.uuid) }

    it 'will create and upgrade an account and set the time this was done' do
      expect(subject.terms_and_conditions_accepted?).to be_truthy
      expect(subject.preexisting_account?).to be_falsey
      expect(subject.persisted?).to be_falsey
      expect(user.mhv_correlation_id).to be_nil
      VCR.use_cassette('mhv_account_creation/creates_an_account') do
        VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
          subject.create_and_upgrade!
          expect(subject.persisted?).to be_truthy
          expect(subject.account_state).to eq('upgraded')
          expect(subject.registered_at).to be_a(Time)
          expect(subject.upgraded_at).to be_a(Time)
          expect(User.find(user.uuid).mhv_correlation_id).to eq('14221465')
          expect(subject.eligible?).to be_truthy
          expect(subject.terms_and_conditions_accepted?).to be_truthy
        end
      end
    end

    context 'existing account that has not been upgraded' do
      let(:mhv_ids) { ['14221465'] }

      it 'will only upgrade an account and set the time the account was upgraded' do
        expect(subject.terms_and_conditions_accepted?).to be_truthy
        expect(subject.preexisting_account?).to be_truthy
        expect(subject.persisted?).to be_falsey
        VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
          subject.create_and_upgrade!
          expect(subject.persisted?).to be_truthy
          expect(subject.account_state).to eq('upgraded')
          expect(subject.registered_at).to be_nil
          expect(subject.upgraded_at).to be_a(Time)
          expect(subject.eligible?).to be_truthy
          expect(subject.terms_and_conditions_accepted?).to be_truthy
        end
      end
    end

    context 'existing account that has already been upgraded' do
      let(:mhv_ids) { ['14221465'] }

      it 'will only update the record to reflect that it has been upgraded' do
        expect(subject.terms_and_conditions_accepted?).to be_truthy
        expect(subject.preexisting_account?).to be_truthy
        expect(subject.persisted?).to be_falsey
        VCR.use_cassette('mhv_account_creation/should_not_upgrade_an_account_if_one_already_exists') do
          subject.create_and_upgrade!
          expect(subject.persisted?).to be_truthy
          expect(subject.account_state).to eq('upgraded')
          expect(subject.registered_at).to be_nil
          expect(subject.upgraded_at).to be_nil
          expect(subject.eligible?).to be_truthy
          expect(subject.terms_and_conditions_accepted?).to be_truthy
        end
      end
    end
  end

  describe 'va_patient eligibility' do
    subject { described_class.new(user_uuid: user.uuid) }
    context 'empty facility list' do
      let(:vha_facility_ids) { [] }
      it 'is ineligible if vha facility list is empty' do
        subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
        subject.send(:setup) # This gets called when object is first loaded
        expect(subject.account_state).to eq('ineligible')
      end
    end

    context 'nil facility list' do
      let(:vha_facility_ids) { nil }
      it 'is ineligible if vha facility list is nil' do
        subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
        subject.send(:setup) # This gets called when object is first loaded
        expect(subject.account_state).to eq('ineligible')
      end
    end

    context 'with single facility' do
      it 'is eligible with facility in range' do
        stub_const('MhvAccount::PATIENT_FACILITY_RANGE', [358, 758])
        subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
        subject.send(:setup) # This gets called when object is first loaded
        expect(subject.account_state).not_to eq('ineligible')
      end
      it 'is eligible with facility at edge of range' do
        stub_const('MhvAccount::PATIENT_FACILITY_RANGE', [450, 758])
        subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
        subject.send(:setup) # This gets called when object is first loaded
        expect(subject.account_state).not_to eq('ineligible')
      end
      it 'is ineligible with facility out of range' do
        stub_const('MhvAccount::PATIENT_FACILITY_RANGE', [600, 758])
        subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
        subject.send(:setup) # This gets called when object is first loaded
        expect(subject.account_state).to eq('ineligible')
      end
    end

    context 'with multiple facilities' do
      let(:vha_facility_ids) { %w(200MH 488) }
      it 'is eligible with at least one facility in range' do
        stub_const('MhvAccount::PATIENT_FACILITY_RANGE', [358, 758])
        subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
        subject.send(:setup) # This gets called when object is first loaded
        expect(subject.account_state).not_to eq('ineligible')
      end
      it 'is ineligible with all facilities out of range' do
        stub_const('MhvAccount::PATIENT_FACILITY_RANGE', [600, 758])
        subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
        subject.send(:setup) # This gets called when object is first loaded
        expect(subject.account_state).to eq('ineligible')
      end
    end

    context 'with alphanumeric facility' do
      let(:vha_facility_ids) { ['566GE'] }
      it 'is eligible with facility in range' do
        stub_const('MhvAccount::PATIENT_FACILITY_RANGE', [358, 758])
        subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
        subject.send(:setup) # This gets called when object is first loaded
        expect(subject.account_state).not_to eq('ineligible')
      end
      it 'is ineligible with facility out of range' do
        stub_const('MhvAccount::PATIENT_FACILITY_RANGE', [600, 758])
        subject = described_class.new(user_uuid: user.uuid, account_state: 'needs_terms_acceptance')
        subject.send(:setup) # This gets called when object is first loaded
        expect(subject.account_state).to eq('ineligible')
      end
    end
  end
end
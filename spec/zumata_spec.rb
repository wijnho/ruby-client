require 'json'
require 'spec_helper'
require './lib/zumata'

describe "Zumata::Client" do

  raise Zumata::TestConfigError unless ENV["ZUMATA_API_KEY"]
  sample_api_key = ENV["ZUMATA_API_KEY"]

  before(:each) do

    Zumata.configure do |config|
      config.api_url = 'staging.internal.api.zumata.com'
    end

    @client = Zumata::Client.new(sample_api_key)
  end

  describe "search_by_destination" do

    it 'returns a response with search completed status if the query is valid', :vcr => { :cassette_name => "search_by_destination_done", :record => :new_episodes } do
    	
      # note - when recording the cassette this requires a cached search w/ results to exist
      destination_id = "f75a8cff-c26e-4603-7b45-1b0f8a5aa100" # Singapore
      results = @client.search_by_destination destination_id
    	data = JSON.parse(results.body)
      expect(data["searchCompleted"]).to_not be(nil)
      expect(data["content"]["hotels"].length).to be > 0
    end

  end

  describe "book (via stripe payment)" do

      def sample_guest
        return {
          :salutation => "Mr",
          :first_name => "Phantom",
          :last_name => "Assassin",
          :email => "jonathanbgomez@gmail.com",
          :street => "1 Random St",
          :city => "Melbourne",
          :state => "VIC",
          :postal_code => "3000",
          :country => "Australia",
          :room_remarks => "Room with a view, please.",
          :nationality => "Australia"
        }
      end

      def sample_payment stripe_token, usd_amount
        amount = ('%.2f' % usd_amount.to_f).to_f
        return {
          :type => "stripe",
          :contact => {
            :first_name => "Phantom",
            :last_name => "Assassin",
            :email => "jonathanbgomez@gmail.com",
            :street => "1 Random St",
            :city => "Melbourne",
            :state => "VIC",
            :postal_code => "3000",
            :country => "Australia"
          },
          :details => {
            :stripe_token => stripe_token,
            :amount => amount,
            :currency => "USD"
          },
          :conversion => {
            :converted_amount => amount,
            :converted_currency => 'USD',
            :exchange_rate => 1.00
          }
        }
      end

      def select_cheapest_package hotels
        cheapest_package_rate = nil
        cheapest_package_key = nil
        hotels.each do |hotel|
          hotel["rates"]["packages"].each do |package|
            if cheapest_package_rate.nil? || package["roomRate"] < cheapest_package_rate
              cheapest_package_rate = package["roomRate"]
              cheapest_package_key = package["key"]
            end
          end
        end
        raise "Error finding cheap package" if cheapest_package_key.nil?
        return cheapest_package_key, cheapest_package_rate
      end

    it 'books the hotel and returns booking information' do
      
      destination_id = "53d32e78-c548-42af-5236-fb89e0977722" # Barcelona
      results = VCR.use_cassette('search_by_destination_done_2', :record => :new_episodes) do
        @client.search_by_destination destination_id
      end
      
      data = JSON.parse(results.body)
      expect(data["searchCompleted"]).to_not be(nil)
        
      cheapest_key, cheapest_rate = select_cheapest_package(data["content"]["hotels"])
      guest_params = sample_guest
      payment_params = sample_payment("tok_14dEyI4Zpcn7UAbK7HFGKKqG", cheapest_rate)

      VCR.use_cassette('book_success', :record => :new_episodes) do
        booking = @client.book cheapest_key, guest_params, payment_params, { api_key: ENV['ZUMATA_API_KEY_BOOK_SUCCESS'] }
        res_body = JSON.parse(booking.body)
        expect(res_body["status"]).to eq(nil)
        expect(res_body["content"]["booking_id"]).not_to eq(nil)
      end

    end

    it 'responds with an error when provided with an invalid api key' do

      destination_id = "f75a8cff-c26e-4603-7b45-1b0f8a5aa100" # Singapore
      results = VCR.use_cassette('search_by_destination_done', :record => :new_episodes) do
        @client.search_by_destination(destination_id)
      end
      
      data = JSON.parse(results.body)
      expect(data["searchCompleted"]).to_not be(nil)
        
      cheapest_key, cheapest_rate = select_cheapest_package(data["content"]["hotels"])
      guest_params = sample_guest
      payment_params = sample_payment("tok_14bquA4Zpcn7UAbKnRf8XRNg", cheapest_rate)

      VCR.use_cassette('book_invalid_api_key', :record => :new_episodes) do
        expect{ @client.book cheapest_key, guest_params, payment_params, { api_key: ENV['ZUMATA_API_KEY_FAKE'] } }.to raise_error(Zumata::InvalidApiKeyError)
      end

    end
   
    it 'responds with an error when the booking key is invalid' do

      # note - create a cached search, then let it expire
      
      destination_id = "f75a8cff-c26e-4603-7b45-1b0f8a5aa100" # Singapore
      results = VCR.use_cassette('search_by_destination_done', :record => :new_episodes) do
        @client.search_by_destination destination_id
      end
      
      data = JSON.parse(results.body)
      expect(data["searchCompleted"]).to_not be(nil)
        
      cheapest_key, cheapest_rate = select_cheapest_package(data["content"]["hotels"])
      guest_params = sample_guest
      payment_params = sample_payment("tok_14bquA4Zpcn7UAbKnRf8XRNg", cheapest_rate)

      VCR.use_cassette('book_invalid_booking_key', :record => :new_episodes) do
        expect{ @client.book cheapest_key, guest_params, payment_params, { api_key: ENV['ZUMATA_API_KEY_BOOK_SUCCESS'] } }.to raise_error(Zumata::InvalidBookingKeyError)
      end

    end

    it 'responds with an error when the booking fails (e.g. stripe is not setup on payment provider)' do
      
      destination_id = "53d32e78-c548-42af-5236-fb89e0977722" # Barcelona
      results = VCR.use_cassette('search_by_destination_done_2', :record => :new_episodes) do
        @client.search_by_destination destination_id
      end
      
      data = JSON.parse(results.body)
      expect(data["searchCompleted"]).to_not be(nil)
        
      cheapest_key, cheapest_rate = select_cheapest_package(data["content"]["hotels"])
      guest_params = sample_guest
      payment_params = sample_payment("tok_14bquA4Zpcn7UAbKnRf8XRNg", cheapest_rate)

      VCR.use_cassette('book_invalid_stripe_setup', :record => :new_episodes) do
        expect{ @client.book cheapest_key, guest_params, payment_params, { api_key: ENV['ZUMATA_API_KEY_NO_STRIPE'] } }.to raise_error(Zumata::TransactionError)
      end

    end

    xit 'responds with an error when the payment is rejected' do
    end

  end
end

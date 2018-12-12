require 'sinatra'
require "sinatra/json"
require "sinatra/reloader"
require 'thin'
require 'pry'
require 'lib/klarna'

if ENV['KLARNA_API_KEY'].nil? && ENV['KLARNA_API_SECRET'].nil?
  raise "KLARNA_API_KEY and KLARNA_API_SECRET environment variables not set"
end

Klarna.configure do |config|
  config.environment = :test
  config.country = ENV.fetch("KLARNA_REGION") { :us }.to_sym
  config.api_key = ENV["KLARNA_API_KEY"]
  config.api_secret = ENV["KLARNA_API_SECRET"]
end

class FakeFrontend < Sinatra::Base
  set :server, 'thin'
  set :sessions, true
  set :reloader, true

  get '/' do
    erb :layout, :layout => false do
      erb :index
    end
  end

  post '/session' do
    unless session.has_key? :token
      req = session_request
      response = Klarna.client(:payments).create_session(req)
      session[:token] = response.client_token
    end
    json token: session[:token]
  end

  delete '/session' do
    session.delete(:token) if session.has_key?(:token)
    json status: true
  end

  post '/order' do
    result = Klarna.client(:payments).place_order(params[:authorization_token], order)
    session.delete(:token) if session.has_key?(:token)

    if result.success?
      json({
        success: result.success?,
        order_id: result.order_id,
        redirect_url: result.body['redirect_url'],
        fraud_status: result.fraud_status
        })
    else
      json({
        success: result.success?,
        error_code: result.error_code,
        error_messages: result.error_messages,
        correlation_id: result.correlation_id
        })
    end
  end
end

def session_request
  data = {
      locale: "en-US",
      order_amount: 10000,
      order_lines: [
          {
              name: "Battery Power Pack",
              quantity: 1,
              total_amount: 10000,
              unit_price: 10000
          }
      ],
      order_tax_amount: 0,
      purchase_country: "US",
      purchase_currency: "USD",
  }
  data.merge!(
      billing_address: params[:billing_address],
      shipping_address: params[:shipping_address]
  )
end

def order
  data = {
    purchase_country: "US",
    purchase_currency: "USD",
    order_amount: 10000,
    order_tax_amount: 0,
    order_lines: [
        {
            name: "Battery Power Pack",
            quantity: 1,
            total_amount: 10000,
            unit_price: 10000
        }
    ]
  }
  data.merge!(
    billing_address: params[:billing_address],
    shipping_address: params[:shipping_address]
  )
end

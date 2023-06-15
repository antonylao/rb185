require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"

require 'sysrandom/securerandom'
require 'yaml'

require 'pry'

require_relative "database_persistence.rb"

REVENUE_CATEGORIES = ["Main Income", "Second Income", "Other Revenues"]
EXPENSE_CATEGORIES = ["Food", "Health", "Bills", "Debt", "Other Expenses"]

configure do
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

# rubocop: disable Metrics/BlockLength
helpers do
  # rubocop: enable Metrics/BlockLength
  def total_revenue_current_month
    current_time = Time.now
    year = current_time.year
    month = current_time.month
    total_revenue(month: month, year: year)
  end

  def total_revenue_current_year
    current_time = Time.now
    year = current_time.year
    total_revenue(year: year)
  end

  # Calculate total revenue of year or month
  # rubocop: disable Metrics/MethodLength
  def total_revenue(year:, month: nil)
    return 0 unless @storage.load_database

    filtered_entries = find_data_entries(month: month, year: year)

    total = 0

    filtered_entries.each do |entry|
      amount = entry["amount"].to_i
      case entry["type"]
      when "expense" then total -= amount
      when "revenue" then total += amount
      end
    end

    total
  end
  # rubocop: enable Metrics/MethodLength

  def format_amount(amount)
    if amount.positive?
      "+$#{amount}"
    elsif amount.negative?
      "-$#{amount.abs}"
    else
      "$#{amount}"
    end
  end

  def find_data_entries(year:, month: nil)
    data_yml = @storage.load_database

    # rubocop: disable Layout/BlockAlignment
    data_filtered = data_yml.select do |_, entry|
                      date = entry["date"]
                      date_match?(date, month: month, year: year)
                    end
    # rubocop: enable Layout/BlockAlignment

    data_filtered.map do |_, entry|
      entry
    end
  end

  def date_match?(date, year:, month: nil)  
    year = year.to_i
    return false unless date.year == year

    if month
      month = month.to_i
      return false unless date.month == month
    end

    true
  end

  # Returns an array with entries sorted from more newest to oldest date-wise.
  # If dates are equal, entries added last are considered older
  def sorted_datafile
    datafile = @storage.load_database
    # rubocop: disable Layout/BlockAlignment
    datafile_arr = datafile.map do |key, hash|
                     hash[:key] = key
                     hash
                   end
    # rubocop: enable Layout/BlockAlignment

    sort_by_date_then_key(datafile_arr)
  end

  def sort_by_date_then_key(arr)
    arr.sort do |hash1, hash2|
      if hash1["date"] != hash2["date"]
        hash2["date"] <=> hash1["date"]
      else
        hash2[:key] <=> hash1[:key]
      end
    end
  end

  def snake_case(str)
    str.downcase.gsub(' ', '_')
  end
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
end

get "/" do
  erb :index
end

get "/new_entry" do
  @type = params[:type]
  if @type.nil?
    session[:message] = "Invalid URL."
    redirect "/"
  end

  @category_options = if @type == "expense"
                        EXPENSE_CATEGORIES
                      else
                        REVENUE_CATEGORIES
                      end
  erb :new_entry
end

get "/log" do
  if @storage.load_database.nil?
    session[:message] = "No entry has been added yet."
    redirect "/"
  end

  erb :log
end

# Add a new expense/revenue to the data yml file
post "/new_entry" do
  type = params["type"]
  category = params["category"]
  amount = params["amount"].to_i
  date = params["date"] # format: yyyy-mm-dd

  @storage.add_entry_to_datafile(type: type, category: category,
                        amount: amount, date: date.to_s)

  # NB: inside datafile, date entry is of Date class!

  session[:message] = "Your #{type} has been successfully added."
  redirect "/"
end

get "/:data_key/edit" do
  @key = params[:data_key]
  entry = @storage.load_entry(@key.to_i)

  @date = entry["date"]
  @type = entry["type"]
  @category = entry["category"]
  @amount = entry["amount"].to_i

  @category_options = if @type == "expense"
                        EXPENSE_CATEGORIES
                      else
                        REVENUE_CATEGORIES
                      end
  
  erb :edit
end

post "/:data_key/update" do
  key = params[:data_key].to_i
  date = Date.parse(params["date"])
  category = params["category"]
  amount = params["amount"].to_i

  @storage.update_entry(key, date, category, amount)

  session[:message] = "The entry has been successfully updated."
  redirect "/log"
end

post "/:data_key/delete" do
  key = params[:data_key].to_i
  @storage.delete_entry(key)

  session[:message] = "The entry has been successfully deleted."
  redirect "/log"
end

ENV["RACK_ENV"] = "test" #this ensures that Sinatra does not start a web server

require "minitest/autorun"
require "rack/test" #require the app method in the test class

require_relative "../budget"

require 'fileutils'
require 'pry'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  # Rack::Test::Methods require a app method that returns an instance of the Rack application
  def app 
    Sinatra::Application
  end

  # access the session hash
  def session
    last_request.env["rack.session"]
  end

  def setup
    @storage = DatafilePersistence.new
  end

  def teardown
    FileUtils.rm(@storage.datafile_path) if File.exist?(@storage.datafile_path)
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, 'Add an expense</a>'
    assert_includes last_response.body, 'Add a revenue</a>'
    assert_includes last_response.body, 'href="/log"'
  end

  def test_new_expense_form
    get "/new_entry?type=expense"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Category"
    EXPENSE_CATEGORIES.each do |category|
      assert_includes last_response.body, category
    end
    assert_includes last_response.body, "Amount"
    assert_includes last_response.body, "Date"
    assert_includes last_response.body, '<button type="submit"' 
    assert_includes last_response.body, "Add expense"
  end

  
  def test_new_revenue_form
    get "/new_entry?type=revenue"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Category"
    REVENUE_CATEGORIES.each do |category|
      assert_includes last_response.body, category
    end
    assert_includes last_response.body, "Amount"
    assert_includes last_response.body, "Date"
    assert_includes last_response.body, '<button type="submit"' 
    assert_includes last_response.body, "Add revenue"
  end
  

  def test_nex_entry_form_no_query_params
    get "/new_entry"
    assert_equal 302, last_response.status
    assert_equal "Invalid URL.", session[:message]
  end

  def test_add_new_expense
    current_date_str = Time.now.to_date.to_s
    post "/new_entry", {type: "expense", category: "food", amount: "08", date: current_date_str}
    assert_equal true, File.exist?(@storage.datafile_path)
    
    entry = <<~ENTRY
      1:
        date: #{current_date_str}
        type: expense
        category: food
        amount: 8
    ENTRY

    assert_includes File.read(@storage.datafile_path), entry

    assert_equal 302, last_response.status
    assert_equal "Your expense has been successfully added.", session[:message]
  end

  def test_add_new_revenue
    current_date_str = Time.now.to_date.to_s
    post "/new_entry", {type: "revenue", category: "main_income", amount: "02200", date: current_date_str}
    
    assert_equal true, File.exist?(@storage.datafile_path)
    
    entry = <<~ENTRY
      1:
        date: #{current_date_str}
        type: revenue
        category: main_income
        amount: 2200
    ENTRY

    assert_includes File.read(@storage.datafile_path), entry

    assert_equal 302, last_response.status
    assert_equal "Your revenue has been successfully added.", session[:message]
  end

  def test_entry_log
    current_date_str = Time.now.to_date.to_s
    post "/new_entry", {type: "revenue", category: "main_income", amount: "02200", date: current_date_str}

    get "/log"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "2200"
    assert_includes last_response.body, "revenue"
    assert_includes last_response.body, "main_income"
    assert_includes last_response.body, current_date_str
    assert_includes last_response.body, "Edit"
    assert_includes last_response.body, "Delete"
  end

  def test_empty_entry_log
    get "/log"
    assert_equal 302, last_response.status
    assert_equal "No entry has been added yet.", session[:message]
  end

  def test_delete_entry
    current_date_str = Time.now.to_date.to_s
    post "/new_entry", {type: "expense", category: "food", amount: "10", date: current_date_str}
    post "/new_entry", {type: "revenue", category: "second_income", amount: "5", date: current_date_str}

    datafile_hash = @storage.load_datafile
    assert_equal 2, datafile_hash.size
    assert_equal true, datafile_hash[1].is_a?(Hash)
    assert_equal true, datafile_hash[2].is_a?(Hash)


    post "2/delete"
    assert_equal 302, last_response.status
    assert_equal "The entry has been successfully deleted.", session[:message]
    
    datafile_hash = @storage.load_datafile
    assert_equal 1, datafile_hash.size
    assert_nil datafile_hash[2]
    assert_equal true, datafile_hash[1].is_a?(Hash)
  end

  def test_edit_revenue_form
    current_date = Time.now.to_date
    post "/new_entry", {type: "revenue", category: "second_income", amount: "5", date: current_date.to_s}

    get "/1/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Category"
    REVENUE_CATEGORIES.each do |category|
      assert_includes last_response.body, category
    end
    assert_includes last_response.body, "Amount"
    assert_includes last_response.body, "Date"
    assert_includes last_response.body, '<button type="submit"' 
    assert_includes last_response.body, "Update revenue"
  end

  def test_edit_expense_form
    current_date = Time.now.to_date
    post "/new_entry", {type: "expense", category: "food", amount: "5", date: current_date.to_s}

    get "/1/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Category"
    EXPENSE_CATEGORIES.each do |category|
      assert_includes last_response.body, category
    end
    assert_includes last_response.body, "Amount"
    assert_includes last_response.body, "Date"
    assert_includes last_response.body, '<button type="submit"' 
    assert_includes last_response.body, "Update expense"
  end

  def test_update_entry
    current_date = Time.now.to_date
    previous_month = current_date.prev_month

    post "/new_entry", {type: "expense", category: "food", amount: "10", date: current_date.to_s}
    post "/new_entry", {type: "revenue", category: "second_income", amount: "5", date: current_date.to_s}

    datafile_hash = @storage.load_datafile
    assert_equal "food", datafile_hash[1]["category"]
    assert_equal 10, datafile_hash[1]["amount"]
    assert_equal current_date, datafile_hash[1]["date"]

    post "/1/update", {type: "expense", category: "health", amount: "15", date: previous_month.to_s}
    assert_equal 302, last_response.status
    assert_equal "The entry has been successfully updated.", session[:message]

    datafile_hash = @storage.load_datafile
    assert_equal "health", datafile_hash[1]["category"]
    assert_equal 15, datafile_hash[1]["amount"]
    assert_equal previous_month, datafile_hash[1]["date"]
  end

  def test_total_revenue_month_and_year
    current_date = Time.now.to_date
    current_date_str = current_date.to_s
    previous_month_str = current_date.prev_month.to_s
    
    post "/new_entry", {type: "expense", category: "food", amount: "10", date: current_date_str}
    get "/"
    assert_includes last_response.body, "Total (current month): -$10"
    assert_includes last_response.body, "Total (current year): -$10"

    post "/new_entry", {type: "expense", category: "bills", amount: "10", date: previous_month_str}
    get "/"
    assert_includes last_response.body, "Total (current month): -$10"
    assert_includes last_response.body, "Total (current year): -$20"

    post "/new_entry", {type: "revenue", category: "second_income", amount: "5", date: previous_month_str}
    get "/"
    assert_includes last_response.body, "Total (current month): -$10"
    assert_includes last_response.body, "Total (current year): -$15"

    post "/new_entry", {type: "revenue", category: "main_income", amount: "10", date: current_date_str}
    get "/"
    assert_includes last_response.body, "Total (current month): $0"
    assert_includes last_response.body, "Total (current year): -$5"

    post "/new_entry", {type: "revenue", category: "second_income", amount: "10", date: previous_month_str}
    get "/"
    assert_includes last_response.body, "Total (current month): $0"
    assert_includes last_response.body, "Total (current year): +$5"
  end
end
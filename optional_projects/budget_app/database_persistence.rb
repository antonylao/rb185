require "pg"
require "date"

class DatabasePersistence
  def initialize(logger)
    dbname = ENV["RACK_ENV"] == "test" ? "rb185_budget_test" : "rb185_budget"
    
    @db = PG.connect(dbname: dbname)
    @logger = logger
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}" unless ENV["RACK_ENV"] == "test"
    @db.exec_params(statement, params)
  end

  def load_database
    sql_nb_of_entries = "SELECT COUNT(id) FROM entries"

    nb_of_entries = query(sql_nb_of_entries).first["count"].to_i
    return nil if nb_of_entries == 0
    

    sql_entries = "SELECT * FROM entries"
    entries = query(sql_entries).to_a

    entries.each do |tuple|
      tuple["amount"] = tuple["amount"].to_i
      tuple["date"] = Date.parse(tuple["date"].to_s)
    end
    
    hash_entries = {}
    entries.each do |tuple|
      hash_entries[tuple["id"].to_i] = tuple.reject { |key, _| key == "id"}
    end

    hash_entries
  end

  def load_entry(key)
    sql = "SELECT * FROM entries WHERE id = $1"
    
    tuple = query(sql, key).first

    tuple["amount"] = tuple["amount"].to_i
    tuple["date"] = Date.parse(tuple["date"].to_s)
    
    tuple
  end
  
  def add_entry_to_datafile(type:, category:, amount:, date:)
    sql = <<~SQL
      INSERT INTO entries (type, category, amount, date)
      VALUES ($1, $2, $3, $4)
    SQL

    query(sql, type, category, amount, date)
  end

  def update_entry(key, date, category, amount)
    sql = <<~SQL
      UPDATE entries
      SET "date" = $1, category = $2, amount = $3
      WHERE id = $4
    SQL

    query(sql, date, category, amount, key)
  end

  def delete_entry(key)
    sql = "DELETE FROM entries WHERE id = $1"

    query(sql, key)
  end
end
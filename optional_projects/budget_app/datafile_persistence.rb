class DatafilePersistence
  def initialize
    @file_hash = load_datafile
  end

  def load_datafile
    return nil unless File.exist?(datafile_path)

    hash = YAML.load_file(datafile_path)
    return nil unless hash

    # change date to Date object, amount to Int object
    hash.each do |_, entry|
      entry["date"] = Date.parse(entry["date"]) if entry["date"].is_a? String
      entry["amount"] = entry["amount"].to_i
    end
  end

  def load_entry(key)
    @file_hash[key]
  end

  def add_entry_to_datafile(type:, category:, amount:, date:)
    File.write(datafile_path, "---\n") unless File.exist?(datafile_path)

    datafile = load_datafile
    next_index = datafile ? datafile.keys.max + 1 : 1

    entry = <<~ENTRY
      #{next_index}:
        date: #{date}
        type: #{type}
        category: #{category}
        amount: #{amount}
    ENTRY
    add_line_to_file(datafile_path, entry)
  end

  def update_entry(key, date, category, amount)
    datafile = load_datafile
    entry = datafile[key]
    entry["date"] = date
    entry["category"] = category
    entry["amount"] = amount

    File.write(datafile_path, datafile.to_yaml)
  end

  def delete_entry(key)
    datafile = load_datafile
    datafile.delete(key)

    File.write(datafile_path, datafile.to_yaml)
  end

  private

  def add_line_to_file(path, line)
    File.open(path, "a") do |file|
      file.write("\n") unless File.readlines(file)[-1].end_with?("\n")
      file.write(line)
    end
  end

  public if ENV["RACK_ENV"] == "test"

  def datafile_path
    # rubocop: disable Style/ExpandPathArguments
    if ENV["RACK_ENV"] == "test"
      File.expand_path("../test/data.yml", __FILE__)
    else
      File.expand_path("../data.yml", __FILE__)
    end
    # rubocop: enable Style/ExpandPathArguments
  end
end
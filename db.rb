class DB
  attr_reader :connection

  def initialize
    @connection = SQLite3::Database.new("#{ENV["MLN_DB_NAME"] || "melon"}.db")

    rows = @connection.execute(%(SELECT name FROM sqlite_master WHERE type='table' AND name='blocks';))

    # No rows means the table containing blocks doesn't exist.
    return if rows.size > 0

    File.open("schema.sql").read.split(";").each do |statement|
      @connection.execute(statement)
    end
  end
end
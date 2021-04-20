class DB
  @@connection = SQLite3::Database.new "melon.db"

  def self.connection
    @@connection
  end

  def self.load_schema
    rows = DB.connection.execute(%(SELECT name FROM sqlite_master WHERE type='table' AND name='blocks';))

    # No rows means the table containing blocks doesn't exist.
    return if rows.size > 0

    File.open("schema.sql").read.split(";").each do |statement|
      DB.connection.execute(statement)
    end
  end
end
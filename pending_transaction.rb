class PendingTransaction
  class << self
    # Returns one pending transaction.
    def first(limit = 1)
      transactions = $db.connection.execute(
        "SELECT payload FROM pending_transactions LIMIT ?", [limit]
      ).flatten

      # Similar to what Rails does, if the user requests the first transaction,
      # we return it, otherwise we'll return an array.
      if limit == 1
        JSON.parse(transactions.first)
      else
        transactions.map { |t| JSON.parse(t) }
      end
    end

    # Adds the transaction to the table of pending transactions unless it's
    # already stored.
    def create(transaction)
      $db.connection.execute(
        "INSERT INTO pending_transactions (id, payload) VALUES (?, ?)",
        [ transaction["id"], transaction.to_json ],
      )
    end

    def delete_by_id(ids)
      ids = Array(ids)

      return if ids.size == 0

      $db.connection.execute(
        "DELETE FROM pending_transactions WHERE id IN( #{ids.map{ |id| "'#{id}'" }.join(",")})"
      )
    end
  end
end
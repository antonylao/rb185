CREATE TYPE expense_or_revenue AS ENUM ('expense', 'revenue');

CREATE TABLE entries (
  id serial PRIMARY KEY,
  amount integer NOT NULL CONSTRAINT amount_pos CHECK(amount >= 0),
  "type" expense_or_revenue NOT NULL,
  category text NOT NULL,
  "date" date NOT NULL DEFAULT NOW(),
  CONSTRAINT entries_category_check
    CHECK ( CASE "type"
            WHEN 'revenue' THEN 
              category IN ('main_income', 'second_income', 'other_revenues')
            WHEN 'expense' THEN
              category IN ('food', 'health', 'bills', 'debt', 'other_expenses')
            END )
);
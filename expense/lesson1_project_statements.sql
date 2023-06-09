
/*chap 7. Database design*/

ALTER SEQUENCE expenses_id_seq RESTART WITH 1; --optional

ALTER TABLE expenses
  ADD CONSTRAINT positive_amount
      CHECK (amount >= 0.01);

/*chap 8. Listing Expenses*/
INSERT INTO expenses (amount, memo, created_on) VALUES (14.56, 'Pencils', NOW());
INSERT INTO expenses (amount, memo, created_on) VALUES (3.29, 'Coffee', NOW());
INSERT INTO expenses (amount, memo, created_on) VALUES (49.99, 'Text Editor', NOW());

/*chap 10. Adding Expenses (CLI command)*/
-- ./expense add 3.59 "More Coffee"
-- ./expense add 45.50 "Gas for Karen's Car"

/*chap 11.*/
-- pg_dump --inserts rb185_lesson1_expenses -t expenses > ./dump_expense_1_11.sql
-- (after following along the drop table expenses from LS) \i dump_expense_1_11.sql
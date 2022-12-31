BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS person (
        person_id SERIAL PRIMARY KEY, 
        full_name TEXT NOT NULL,
        email TEXT,
        phone_number TEXT
    );
	
CREATE TABLE IF NOT EXISTS card (
        card_id SERIAL PRIMARY KEY, 
        title TEXT NOT NULL, 
        capacity INTEGER NOT NULL
    );

CREATE TABLE IF NOT EXISTS punch (
        punch_id SERIAL PRIMARY KEY, 
        puncher_id INTEGER NOT NULL, 
        card_id INTEGER NOT NULL, 
        date TIMESTAMPTZ NOT NULL, 
        reason TEXT NOT NULL,
        FOREIGN KEY(puncher_id) REFERENCES person(person_id),
        FOREIGN KEY(card_id) REFERENCES card(card_id)
    );
	
INSERT INTO card VALUES(1,'Alice''s Card',10);
INSERT INTO card VALUES(2,'Bob''s Fun Card',5);
INSERT INTO card VALUES(3,'Charlie''s Card',20);
INSERT INTO person VALUES(1,'Alice', 'alice@example.com', '4355121155');
INSERT INTO person VALUES(2,'Bob', 'bob@example.com', '4355121155');
INSERT INTO person VALUES(3,'Charlie', 'charlie@example.com', '4355121155');
INSERT INTO person VALUES(4,'Danica', 'danica@example.com', '4355121155');
INSERT INTO person VALUES(5,'Eric', 'eric@example.com', '4355121155');
INSERT INTO person VALUES(6,'Fan', 'fan@example.com', '4355121155');
INSERT INTO person VALUES(7,'George', 'george@example.com', '4355121155');
INSERT INTO person VALUES(8,'Harry','harry@example.com','4355121155');
INSERT INTO person VALUES(9,'Inez','inez@example.com','4355121155');

COMMIT;

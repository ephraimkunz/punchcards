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
        FOREIGN KEY(puncher_id) REFERENCES person(person_id) ON DELETE CASCADE,
        FOREIGN KEY(card_id) REFERENCES card(card_id) ON DELETE CASCADE
    );

COMMIT;

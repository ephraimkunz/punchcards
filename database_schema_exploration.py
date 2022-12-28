import sqlite3
import time
import datetime

# Explore the possible schema for the punchcards project by creating fake data
# and seeing what queries with that data look like.

# DB Browser for Sqlite (https://sqlitebrowser.org) or the sqlite3 commandline tool
# on macOS can be used to introspect the created database.

def connect_to_db():
    conn = sqlite3.connect('example.db')
    
    return conn

def drop_existing_tables(conn):
    cur = conn.cursor()
    tables = ["punch", "card", "user", "user_card", "role"]

    for table in tables:
        cur.execute(f"DROP TABLE IF EXISTS {table};")
    
    conn.commit()

def create_database_tables(conn):
    cur = conn.cursor()

    cur.execute("PRAGMA foreign_keys = ON;")

    punch_table = '''CREATE TABLE punch (
        punch_id INTEGER PRIMARY KEY, 
        puncher_id INTEGER NOT NULL, 
        card_id INTEGER NOT NULL, 
        date INTEGER NOT NULL, 
        reason TEXT NOT NULL,
        FOREIGN KEY(puncher_id) REFERENCES user(user_id),
        FOREIGN KEY(card_id) REFERENCES card(card_id)
    )'''

    card_table = '''CREATE TABLE card (
        card_id INTEGER PRIMARY KEY, 
        title TEXT NOT NULL, 
        capacity INTEGER NOT NULL
    )'''

    user_table = '''CREATE TABLE user (
        user_id INTEGER PRIMARY KEY, 
        name TEXT NOT NULL
    )'''

    user_card_table = '''CREATE TABLE user_card (
        user_id INTEGER NOT NULL, 
        card_id INTEGER NOT NULL, 
        role_id INTEGER NOT NULL, 
        FOREIGN KEY(user_id) REFERENCES user(user_id),
        FOREIGN KEY(card_id) REFERENCES card(card_id),
        FOREIGN KEY(role_id) REFERENCES role(role_id)
    )'''   

    role_table = '''CREATE TABLE role (
        role_id INTEGER PRIMARY KEY, 
        name TEXT NOT NULL
    )'''  

    default_roles = '''
        INSERT INTO role (name) VALUES 
        ("creator"), /* implies readwrite */
        ("subject"), /* implies readonly */
        ("readwrite"),
        ("readonly");
    ''' 

    cur.execute(punch_table)
    cur.execute(card_table)
    cur.execute(user_table)
    cur.execute(user_card_table)
    cur.execute(role_table)
    cur.execute(default_roles)
        
    conn.commit()

def fill_with_fake_data(conn):
    cur = conn.cursor()
    cur.execute('''INSERT INTO user(name) VALUES 
        ("Alice"),
        ("Bob"),
        ("Charlie"),
        ("Danica"),
        ("Eric"),
        ("Fan"),
        ("George"),
        ("Harry"),
        ("Inez");
    ''')

    cur.execute('''INSERT INTO card(title, capacity) VALUES 
        ("Alice's Card", 10),
        ("Bob's Fun Card", 5),
        ("Charlie's Card", 20);
    ''')

    cur.execute('''INSERT INTO user_card(user_id, card_id, role_id) VALUES 
        (2, 1, 1), /* Bob created Alice's card */
        (1, 1, 2), /* Alice is the subject of the card */
        (4, 1, 4), /* Danica also has readonly access to Alice's card */

        (3, 2, 1), /* Charlie created Bob's card */
        (2, 2, 2), /* Bob is the subject of the card */

        (6, 3, 1), /* Fan created Charlie's card */
        (3, 3, 2), /* Charlie is the subject of the card */
        (9, 3, 4), /* Inez also has readonly access to Charlie's card */
        (7, 3, 3); /* George also has readwrite access to Charlie's card */
    ''')

    conn.commit()

def add_some_punches(conn):
    cur = conn.cursor()

    now = datetime.datetime.now()
    punches = [
        (5, 1, now, "I wanted to"),
        (1, 2, now + datetime.timedelta(0, 5), "You were bad"),
        (7, 3, now + datetime.timedelta(0, 15), "Soo cool"),
    ]

    cur.executemany("INSERT INTO punch(puncher_id, card_id, date, reason) VALUES (?, ?, ?, ?);", punches)
    conn.commit()

def remove_some_punches(conn):
    cur = conn.cursor()
    conn.execute("DELETE FROM punch;")
    conn.commit()

def modify_some_punches(conn):
    cur = conn.cursor()
    cur.execute("UPDATE punch SET date = ?", (datetime.datetime.now(), ))
    conn.commit()

def print_cards(conn):
    cur = conn.cursor()

    card_query = cur.execute("SELECT * FROM card;")

    for card in card_query.fetchall():
        card_id = int(card[0])
        card_title = card[1]
        card_capacity = card[2]

        particiant_query = cur.execute("SELECT u.name, r.name FROM user_card uc JOIN user u ON uc.user_id = u.user_id JOIN role r ON uc.role_id = r.role_id WHERE uc.card_id = ?", (card_id,))
        participants = particiant_query.fetchall()

        punches_query = cur.execute("SELECT p.date, p.reason, u.name FROM punch p JOIN user u ON p.puncher_id = u.user_id WHERE p.card_id = ?", (card_id,))
        punches = punches_query.fetchall()
        
        print(f"\"{card_title}\"\nAvailable slots: {card_capacity - len(punches)} / {card_capacity}")
        print(f"Participants:")
        for participant in participants:
            print(f"\t{participant[0]} - {participant[1]}")
        
        if len(punches) > 0:
            print(f"Punches:")
            for punch in punches:
                print(f"At {datetime.datetime.fromtimestamp(punch[0])} by {punch[2]} - {punch[1]}")
        print("\n")
    
def adapt_datetime(ts: datetime.datetime):
    return time.mktime(ts.timetuple())

def main():
    sqlite3.register_adapter(datetime.datetime, adapt_datetime)

    conn = connect_to_db()
    drop_existing_tables(conn)
    create_database_tables(conn)

    print("----Initial state----")
    fill_with_fake_data(conn)
    print_cards(conn)

    print("----Add some punches----")
    add_some_punches(conn)
    print_cards(conn)

    print("----Modify some punches----")
    modify_some_punches(conn)
    print_cards(conn)

    print("----Remove some punches----")
    remove_some_punches(conn)
    print_cards(conn)

    conn.close()

if __name__ == "__main__":
    main()



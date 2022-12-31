#[macro_use]
extern crate rocket;

use anyhow::{anyhow, Result};
use async_trait::async_trait;
use punchcards_core::{CardPunch, CreateCard, CreatePerson, CreatePunch, FullCard, Person};
use rocket::http::Status;
use rocket::{routes, serde::json::Json, State};
use serde::Serialize;
use shuttle_service::{error::CustomError, ShuttleRocket};
use sqlx::migrate::Migrator;
use sqlx::types::chrono::{self, Utc};
use sqlx::{FromRow, PgPool, Row};

struct AppState {
    pool: PgPool,
}

#[derive(Serialize, Debug, FromRow)]
struct Card {
    #[sqlx(rename = "card_id")]
    pub id: i32,
    pub title: String,
    pub capacity: i32,
}

impl Card {
    pub async fn all_cards(pool: &PgPool) -> Result<Vec<Self>> {
        let cards: Vec<_> = sqlx::query_as("SELECT * FROM card").fetch_all(pool).await?;

        Ok(cards)
    }

    pub async fn delete(id: i32, pool: &PgPool) -> Result<()> {
        let rows_affected = sqlx::query("DELETE FROM card WHERE card_id = $1")
            .bind(id)
            .execute(pool)
            .await?
            .rows_affected();

        if rows_affected == 0 {
            return Err(anyhow!("Delete didn't actually delete anything"));
        }

        sqlx::query("DELETE FROM punch WHERE card_id = $1")
            .bind(id)
            .execute(pool)
            .await?;

        Ok(())
    }

    pub async fn find_by_id(id: i32, pool: &PgPool) -> Result<Self> {
        let card: Card =
            sqlx::query_as("SELECT card_id, title, capacity FROM card where card_id = $1")
                .bind(id)
                .fetch_one(pool)
                .await?;

        Ok(card)
    }

    async fn create(create: CreateCard, pool: &PgPool) -> Result<Self> {
        let row =
            sqlx::query("INSERT INTO card (title, capacity) VALUES ($1, $2) RETURNING card_id")
                .bind(&create.title)
                .bind(create.capacity)
                .fetch_one(pool)
                .await?;

        let punch = Card {
            id: row.get(0),
            title: create.title,
            capacity: create.capacity,
        };

        Ok(punch)
    }
}

#[async_trait]
trait DBFullCard {
    async fn all_cards(pool: &PgPool) -> Result<Vec<FullCard>>;
}

#[async_trait]
impl DBFullCard for FullCard {
    async fn all_cards(pool: &PgPool) -> Result<Vec<FullCard>> {
        let cards = Card::all_cards(pool).await?;
        let punch_requests = cards.iter().map(|c| CardPunch::punches(c.id, pool));

        let punches = futures::future::try_join_all(punch_requests).await?;
        let full_cards: Vec<_> = cards
            .into_iter()
            .zip(punches)
            .map(|card_punches| FullCard {
                id: card_punches.0.id,
                title: card_punches.0.title,
                capacity: card_punches.0.capacity,
                punches: card_punches.1,
            })
            .collect();

        Ok(full_cards)
    }
}

#[async_trait]
trait DBPerson {
    async fn all_persons(pool: &PgPool) -> Result<Vec<Person>>;
    async fn create(create: CreatePerson, pool: &PgPool) -> Result<Person>;
}

#[async_trait]
impl DBPerson for Person {
    async fn all_persons(pool: &PgPool) -> Result<Vec<Person>> {
        let rows = sqlx::query("SELECT person_id, full_name, email, phone_number FROM person")
            .fetch_all(pool)
            .await?;

        let people: Vec<_> = rows
            .into_iter()
            .map(|r| Person {
                id: r.get(0),
                name: r.get(1),
                email: r.get(2),
                phone_number: r.get(3),
            })
            .collect();

        Ok(people)
    }

    async fn create(create: CreatePerson, pool: &PgPool) -> Result<Self> {
        let row = sqlx::query("INSERT INTO person (full_name, email, phone_number) VALUES ($1, $2, $3) RETURNING person_id")
            .bind(&create.name)
            .bind(&create.email)
            .bind(&create.phone_number)
            .fetch_one(pool)
            .await?;

        let person = Person {
            id: row.get(0),
            name: create.name,
            email: create.email,
            phone_number: create.phone_number,
        };

        Ok(person)
    }
}

#[derive(Debug, Serialize)]
struct Punch {
    pub id: i32,
    pub card_id: i32,
    pub puncher_id: i32,
    pub date: chrono::DateTime<Utc>,
    pub reason: String,
}

impl Punch {
    async fn create(create: CreatePunch, pool: &PgPool) -> Result<Self> {
        // The database will catch errors like puncher_id or card_id not referencing real things.
        // At some point we might want to check those up here and return better errors.
        // For now, just check for stuff the database can't validate.

        // Check that we haven't exceeded the punch limit for the card. Note that there is a concurrency bug
        // here where multiple concurrent punchers would both be able to punch. Since I don't expect concurrent
        // writes to the same card, it's fine for now.
        // See https://dba.stackexchange.com/questions/167273/how-to-perform-conditional-insert-based-on-row-count
        // for what would need to be done to make this safe for concurrent writes.
        let card_capacity = Card::find_by_id(create.card_id, pool).await?.capacity;
        let current_punch_count = Punch::current_punch_count(create.card_id, pool).await?;
        if current_punch_count >= card_capacity as i64 {
            return Err(anyhow!(
                "Can't punch a card with no unpunched spots remaining"
            ));
        }

        let row =
            sqlx::query("INSERT INTO punch (puncher_id, card_id, date, reason) VALUES ($1, $2, $3, $4) RETURNING punch_id")
                .bind(create.puncher_id)
                .bind(create.card_id)
                .bind(create.date)
                .bind(&create.reason)
                .fetch_one(pool)
                .await?;

        let punch = Punch {
            id: row.get(0),
            card_id: create.card_id,
            puncher_id: create.puncher_id,
            date: create.date,
            reason: create.reason,
        };

        Ok(punch)
    }

    pub async fn current_punch_count(card_id: i32, pool: &PgPool) -> Result<i64> {
        let row = sqlx::query("SELECT COUNT(*) FROM punch WHERE card_id = $1")
            .bind(card_id)
            .fetch_one(pool)
            .await?;

        Ok(row.get(0))
    }
}

#[async_trait]
trait DBCardPunch {
    async fn punches(card_id: i32, pool: &PgPool) -> Result<Vec<CardPunch>>;
}

#[async_trait]
impl DBCardPunch for CardPunch {
    async fn punches(card_id: i32, pool: &PgPool) -> Result<Vec<CardPunch>> {
        let rows = sqlx::query(
            "SELECT punch_id, date, reason, person_id, full_name, email, phone_number FROM punch JOIN person on puncher_id = person_id WHERE card_id = $1",
        )
        .bind(card_id)
        .fetch_all(pool)
        .await?;

        let punches = rows
            .iter()
            .map(|row| CardPunch {
                id: row.get(0),
                date: row.get(1),
                reason: row.get(2),
                puncher: Person {
                    id: row.get(3),
                    name: row.get(4),
                    email: row.get(5),
                    phone_number: row.get(6),
                },
            })
            .collect();

        Ok(punches)
    }
}

#[get("/")]
async fn get_all_persons(state: &State<AppState>) -> Result<Json<Vec<Person>>, Status> {
    match Person::all_persons(&state.pool).await {
        Ok(persons) => Ok(Json(persons)),
        Err(e) => {
            tracing::error!("{:?}", e);
            Err(Status::BadRequest)
        }
    }
}

#[post("/", data = "<create>")]
async fn post_person(
    create: Json<CreatePerson>,
    state: &State<AppState>,
) -> Result<Json<Person>, Status> {
    match Person::create(create.0, &state.pool).await {
        Ok(person) => Ok(Json(person)),
        Err(e) => {
            tracing::error!("{:?}", e);
            Err(Status::BadRequest)
        }
    }
}

#[get("/")]
async fn get_all_cards(state: &State<AppState>) -> Result<Json<Vec<FullCard>>, Status> {
    match FullCard::all_cards(&state.pool).await {
        Ok(cards) => Ok(Json(cards)),
        Err(e) => {
            tracing::error!("{:?}", e);
            Err(Status::BadRequest)
        }
    }
}

#[delete("/<id>")]
async fn delete_card(id: i32, state: &State<AppState>) -> Status {
    match Card::delete(id, &state.pool).await {
        Ok(_) => Status::NoContent,
        e => {
            tracing::error!("{:?}", e);
            Status::NotFound
        }
    }
}

#[post("/", data = "<create>")]
async fn post_card(
    create: Json<CreateCard>,
    state: &State<AppState>,
) -> Result<Json<Card>, Status> {
    match Card::create(create.0, &state.pool).await {
        Ok(card) => Ok(Json(card)),
        e => {
            tracing::error!("{:?}", e);
            Err(Status::BadRequest)
        }
    }
}

#[post("/", data = "<create>")]
async fn post_punch(
    create: Json<CreatePunch>,
    state: &State<AppState>,
) -> Result<Json<Punch>, Status> {
    match Punch::create(create.0, &state.pool).await {
        Ok(punch) => Ok(Json(punch)),
        e => {
            tracing::error!("{:?}", e);
            Err(Status::BadRequest)
        }
    }
}

static MIGRATOR: Migrator = sqlx::migrate!();

#[shuttle_service::main]
async fn rocket(#[shuttle_shared_db::Postgres] pool: PgPool) -> ShuttleRocket {
    MIGRATOR.run(&pool).await.map_err(CustomError::new)?;

    let state = AppState { pool };
    let rocket = rocket::build()
        .mount("/person", routes![post_person])
        .mount("/persons", routes![get_all_persons])
        .mount("/card", routes![post_card, delete_card])
        .mount("/cards", routes![get_all_cards])
        .mount("/punch", routes![post_punch])
        .manage(state);

    Ok(rocket)
}

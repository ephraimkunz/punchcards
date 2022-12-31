use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize, Debug)]
pub struct CreateCard {
    pub title: String,
    pub capacity: i32,
}

#[derive(Deserialize, Serialize, Debug)]
pub struct CreatePunch {
    pub card_id: i32,
    pub puncher_id: i32,
    pub date: chrono::DateTime<chrono::Utc>,
    pub reason: String,
}

#[derive(Deserialize, Serialize, Debug)]
pub struct CreatePerson {
    pub name: String,
    pub email: Option<String>,
    pub phone_number: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct FullCard {
    pub id: i32,
    pub title: String,
    pub capacity: i32,
    pub punches: Vec<CardPunch>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct CardPunch {
    pub id: i32,
    pub puncher: Person,
    pub date: chrono::DateTime<chrono::Utc>,
    pub reason: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Person {
    pub id: i32,
    pub name: String,
    pub email: Option<String>,
    pub phone_number: Option<String>,
}

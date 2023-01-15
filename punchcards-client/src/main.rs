use anyhow::Result;
use chrono::prelude::*;
use console::Term;
use punchcards_core::{CreateCard, CreatePerson, CreatePunch, FullCard, Person};
use std::io::Write;

const SERVER: &str = "https://punchcards-server.shuttleapp.rs";
// const SERVER: &str = "http://127.0.0.1:8000";

const MENU_WITH_NO_EXISTING: [&str; 2] = ["Create new", "Quit"];
const MENU_WITH_EXISTING: [&str; 4] = ["Punch existing", "Create new", "Delete existing", "Quit"];

fn main() -> Result<()> {
    loop {
        Term::stdout().clear_screen()?;
        let cards: Vec<FullCard> = ureq::get(&format!("{SERVER}/cards")).call()?.into_json()?;
        display_cards(&cards)?;

        let no_existing = cards.is_empty();
        let menu_items = if no_existing {
            &MENU_WITH_NO_EXISTING[..]
        } else {
            &MENU_WITH_EXISTING[..]
        };
        let menu_selection = dialoguer::Select::new()
            .items(menu_items)
            .with_prompt("Punch Cards")
            .default(0)
            .interact()?;

        match (no_existing, menu_selection) {
            (true, 0) => {
                create_new_card()?;
            }
            (true, 1) => break,
            (false, 0) => {
                punch_card(&cards)?;
            }
            (false, 1) => {
                create_new_card()?;
            }
            (false, 2) => {
                delete_existing_card(&cards)?;
            }
            (false, 3) => break,
            _ => unreachable!("Menu selection disallowed"),
        }
    }
    Ok(())
}

fn punch_card(cards: &[FullCard]) -> Result<()> {
    let items: Vec<_> = cards
        .iter()
        .map(|i| format!("{} - {} / {}", i.title, i.punches.len(), i.capacity))
        .collect();
    if let Some(to_punch) = dialoguer::Select::new()
        .items(&items)
        .with_prompt("Punch this card")
        .interact_opt()?
    {
        let mut people: Vec<Person> = ureq::get(&format!("{SERVER}/persons"))
            .call()?
            .into_json()?;
        let mut items: Vec<_> = people.iter().map(|p| format!("\"{}\"", p.name)).collect();
        items.push("Create new person".to_string());
        if let Some(index) = dialoguer::Select::new()
            .items(&items)
            .with_prompt("Who are you?")
            .interact_opt()?
        {
            let puncher = if index == items.len() - 1 {
                let name: String = dialoguer::Input::new()
                    .with_prompt("New person name")
                    .interact_text()?;
                let email: String = dialoguer::Input::new()
                    .with_prompt("New person email")
                    .allow_empty(true)
                    .interact_text()?;
                let phone_number: String = dialoguer::Input::new()
                    .with_prompt("New person phone number")
                    .allow_empty(true)
                    .interact_text()?;
                let person: Person = ureq::post(&format!("{SERVER}/person"))
                    .send_json(CreatePerson {
                        name,
                        email: if email.is_empty() { None } else { Some(email) },
                        phone_number: if phone_number.is_empty() {
                            None
                        } else {
                            Some(phone_number)
                        },
                    })?
                    .into_json()?;
                person
            } else {
                people.remove(index)
            };

            let reason: String = dialoguer::Input::new()
                .with_prompt("Reason")
                .interact_text()?;

            let status = ureq::post(&format!("{SERVER}/punch"))
                .send_json(CreatePunch {
                    card_id: cards[to_punch].id,
                    puncher_id: puncher.id,
                    date: Utc::now(),
                    reason,
                })?
                .status();

            if status != 201 {
                Term::stderr().write_line(&format!("Error creating punch: {status}"))?;
            }
        }
    }

    Ok(())
}

fn create_new_card() -> Result<()> {
    let title: String = dialoguer::Input::new()
        .with_prompt("Card title")
        .interact_text()?;
    let capacity: i32 = dialoguer::Input::new()
        .with_prompt("Number of punch slots")
        .default(10)
        .interact()?;
    let create = CreateCard { title, capacity };
    let status = ureq::post(&format!("{SERVER}/card"))
        .send_json(create)?
        .status();
    if status != 200 {
        Term::stderr().write_line(&format!("Error creating card: {status}"))?;
    }

    Ok(())
}

fn delete_existing_card(cards: &[FullCard]) -> Result<()> {
    let items: Vec<_> = cards
        .iter()
        .map(|i| format!("{} - {} / {}", i.title, i.punches.len(), i.capacity))
        .collect();
    if let Some(index) = dialoguer::Select::new()
        .items(&items)
        .with_prompt("Delete this card")
        .interact_opt()?
    {
        if dialoguer::Confirm::new()
            .with_prompt(&format!(
                "Are you sure you want to delete {}?",
                items[index]
            ))
            .interact()?
        {
            let id = cards[index].id;
            let status = ureq::delete(&format!("{SERVER}/card/{id}"))
                .call()?
                .status();
            if status != 204 {
                Term::stderr()
                    .write_line(&format!("Error deleting card with id {id}: {status}"))?;
            }
        }
    }

    Ok(())
}

fn display_cards(cards: &[FullCard]) -> Result<()> {
    if !cards.is_empty() {
        Term::stdout().write_line("\nExisting cards:")?;

        for card in cards {
            let title_line = if card.capacity == card.punches.len() as i32 {
                format!("\"{}\" - all {} slots punched", card.title, card.capacity)
            } else {
                format!(
                    "\"{}\" - {} / {} unpunched",
                    card.title,
                    card.capacity - card.punches.len() as i32,
                    card.capacity
                )
            };
            writeln!(Term::stdout(), "{}", title_line)?;

            for punch in &card.punches {
                let local_date: DateTime<Local> = DateTime::from(punch.date);

                writeln!(
                    Term::stdout(),
                    "\tPunched by {} on {}: \"{}\"",
                    punch.puncher.name,
                    local_date.format("%a, %b %e at %I:%M %P"),
                    punch.reason
                )?;
            }
        }
    } else {
        Term::stdout().write_line("\nNo existing cards")?;
    }

    Term::stdout().write_line("")?;

    Ok(())
}

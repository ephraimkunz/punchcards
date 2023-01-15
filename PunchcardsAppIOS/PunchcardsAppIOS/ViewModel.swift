//
//  ViewModel.swift
//  PunchcardsAppIOS
//
//  Created by Ephraim Kunz on 1/14/23.
//

import Combine
import Foundation

private let base_url = "https://punchcards-server.shuttleapp.rs"

class ViewModel: ObservableObject {
    @Published var cards: [Card] = []
    
    init() {
        fetchCards()
    }
    
    func addCard(_ addCard: AddCard) {
        let data: Data
        do {
            data = try JSONEncoder().encode(addCard)
        } catch let error {
            print("Error encoding: ", error)
            return
        }
        
        let url = URL(string: base_url + "/card")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.httpBody = data
        
        let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Post error: ", error)
                return
            }
            
            guard let response = response as? HTTPURLResponse else { return }
            
            if response.statusCode != 201 {
                print("Post error: status code \(response.statusCode) does not equal 201 Created")
            }
            
            // For now, just refetch the whole list.
            self.fetchCards()
        }
        
        dataTask.resume()
    }
    
    func deleteCard(_ card: Card) {
        let id = card.id
        
        let url = URL(string: base_url + "/card/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Delete error: ", error)
                return
            }
            
            guard let response = response as? HTTPURLResponse else { return }
            
            if response.statusCode != 204 {
                print("Delete error: status code \(response.statusCode) does not equal 204 No Content")
            }
            
            // For now, just refetch the whole list.
            self.fetchCards()
        }
        
        dataTask.resume()
    }
    
    func fetchCards() {
        let url = URL(string: base_url + "/cards")!
        let urlRequest = URLRequest(url: url)
        let dataTask = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("Request error: ", error)
                return
            }
            
            guard let response = response as? HTTPURLResponse else { return }
            
            if response.statusCode == 200 {
                guard let data = data else { return }
                DispatchQueue.main.async {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .customISO8601
                        let decodedCards = try decoder.decode([Card].self, from: data)
                        self.cards = decodedCards
                    } catch let error {
                        print("Error decoding: ", error)
                    }
                }
            }
        }
        
        dataTask.resume()
    }
}

struct Card: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String
    let capacity: Int
    let punches: [Punch]
    
    struct Punch: Identifiable, Decodable, Hashable {
        let id: Int
        let date: Date
        let reason: String
        let puncher: Person
    }
}

struct Person: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let email: String?
    let phoneNumber: String?
}

struct AddCard: Codable {
    let title: String
    let capacity: Int
}

extension Formatter {
    static let iso8601withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension JSONDecoder.DateDecodingStrategy {
    static let customISO8601 = custom {
        let container = try $0.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = Formatter.iso8601withFractionalSeconds.date(from: string) ?? Formatter.iso8601.date(from: string) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
    }
}

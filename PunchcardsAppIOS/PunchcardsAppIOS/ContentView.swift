//
//  ContentView.swift
//  PunchcardsAppIOS
//
//  Created by Ephraim Kunz on 1/14/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()
    
    @State private var showAddCard = false
    @State private var showDeleteConfirmation = false
    @State private var cardToDelete: Card? = nil
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.cards) { card in
                    Section {
                        NavigationLink(value: card) {
                            CardSummary(viewModel: viewModel, card: card)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                cardToDelete = card
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: Card.self, destination: { card in
                CardDetailsView(viewModel: viewModel, card: card)
            })
            .navigationTitle("Cards")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showAddCard = true
                    } label: {
                        Image(systemName: "plus")
                    }

                }
            }
        }
        .sheet(isPresented: $showAddCard) {
            AddCardView(viewModel: viewModel)
        }
        .confirmationDialog("Are you sure you want to delete \"\(cardToDelete?.title ?? "")\"?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(role: .cancel) {
            } label: {
                Text("Cancel")
            }
            
            Button(role: .destructive) {
                if let cardToDelete {
                    viewModel.deleteCard(cardToDelete)
                }
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct CardDetailsView: View {
    @ObservedObject var viewModel: ViewModel
    let card: Card
    
    var body: some View {
        Text(card.title)
    }
}
struct AddCardView: View {
    @ObservedObject var viewModel: ViewModel
    @State var title = ""
    @State var capacity = 10
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                Stepper("Capacity: \(capacity)", value: $capacity, in: 1...50)
            }
            .navigationTitle("Create New Card")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.addCard(AddCard(title: title, capacity: capacity))
                        dismiss()
                    } label: {
                        Text("Save")
                    }
                    .bold()
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct CardSummary: View {
    @ObservedObject var viewModel: ViewModel
    var card: Card
        
    func punch(index: Int) -> Card.Punch? {
        return hasPunch(index: index) ? card.punches[index] : nil
    }
    
    func hasPunch(index: Int) -> Bool {
        return index < card.punches.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(.title)
            
            HStack(spacing: 2) {
                ForEach(0..<card.capacity, id: \.self) { slotIndex in
                    Image(systemName: hasPunch(index: slotIndex) ? "x.circle.fill" : "circle" )
                        .imageScale(.small)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

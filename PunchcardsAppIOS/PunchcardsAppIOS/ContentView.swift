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
    
    @State private var selectedCard: Card? = nil
    
    var body: some View {
        NavigationSplitView {
            List(viewModel.cards, selection: $selectedCard) { card in
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
        } detail: {
            if let selectedCard {
                CardDetailsView(viewModel: viewModel, card: selectedCard)
            } else {
                Text("Pick a card")
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
    
    @State private var showAddPunch = false
    
    let numCols = 2
    
    var numRows: Int {
        Int(ceil(CGFloat(card.capacity) / CGFloat(numCols)))
    }
    
    func hasPunch(index: Int) -> Bool {
        return index < card.punches.count
    }
    
    var body: some View {
        ScrollView {
            Grid(horizontalSpacing: 0, verticalSpacing: 30) {
                ForEach(0..<numRows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<numCols, id: \.self) { col in
                            let index = row * numCols + col
                            if index < card.capacity {
                                cardDetails(index: index)
                            }
                            
                            if col < (numCols - 1) {
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(card.title)
    }
    
    @ViewBuilder
    func cardDetails(index: Int) -> some View {
        if hasPunch(index: index) {
            VStack(spacing: 10) {
                Image(systemName: "x.circle.fill")
                    .imageScale(.large)
                    .font(.title)
                
                VStack (alignment: .leading) {
                    Grid {
                        GridRow {
                            Image(systemName: "calendar.badge.clock")
                                .gridColumnAlignment(.trailing)
                            Text("\(card.punches[index].date, formatter: dateFormatter)")
                                .gridColumnAlignment(.leading)
                        }
                        
                        GridRow {
                            Image(systemName: "person")
                            Text("\(card.punches[index].puncher.name)")
                        }
                        
                        GridRow {
                            Image(systemName: "note.text")
                            Text("\(card.punches[index].reason)")
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                }
            }
        } else {
            HStack {
                Spacer()
                Button {
                    showAddPunch = true
                } label: {
                    Image(systemName: "circle")
                        .imageScale(.large)
                        .font(.title)
                }
                .sheet(isPresented: $showAddPunch) {
                    AddPunchView(viewModel: viewModel, card: card)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }

                Spacer()
            }
        }
    }
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct AddPunchView: View {
    @ObservedObject var viewModel: ViewModel
    let card: Card
    @State private var reason = ""
    @State private var puncher: Person
    @State private var addPersonSheet = false
    
    init(viewModel: ViewModel, card: Card) {
        self.viewModel = viewModel
        self.card = card
        _puncher = State(initialValue: viewModel.people.first!)
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section("Puncher") {
                Picker("", selection: $puncher) {
                    ForEach(viewModel.people, id: \.self) { person in
                        Text(person.name).id(person)
                    }
                }
                .pickerStyle(.automatic)
                .labelsHidden()
                
                Button {
                    addPersonSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add person")
                    }
                }
                .sheet(isPresented: $addPersonSheet) {
                    AddPersonView(viewModel: viewModel)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
            
            Section("Reason") {
                TextField("", text: $reason, prompt: Text("Ex: Bad behavior"))
            }
            
            Button("Punch card", role: .destructive) {
                viewModel.addPunch(AddPunch(cardId: card.id, puncherId: puncher.id, date: Date(), reason: reason))
                dismiss()
            }
            .disabled(reason.isEmpty)
        }
    }
}

struct AddPersonView: View {
    @ObservedObject var viewModel: ViewModel

    @State private var name = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            TextField("Name", text: $name)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.words)
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField("Phone number", text: $phoneNumber)
                .keyboardType(.phonePad)
            Button("Create person") {
                viewModel.addPerson(AddPerson(name: name, email: email, phoneNumber: phoneNumber))
                dismiss()
            }
            .disabled(name.isEmpty)
        }
    }
}

struct PunchesGrid: View {
    let card: Card
    let numCols: Int
    let includeReasons: Bool
    
    var numRows: Int {
        Int(ceil(CGFloat(card.capacity) / CGFloat(numCols)))
    }
    
    func hasPunch(index: Int) -> Bool {
        return index < card.punches.count
    }
    
    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<numRows, id: \.self) { row in
                GridRow {
                    ForEach(0..<numCols, id: \.self) { col in
                        let index = row * numCols + col
                        if index < card.capacity {
                            if includeReasons && hasPunch(index: index) {
                                VStack {
                                    Image(systemName: "x.circle.fill")
                                        .imageScale(.small)
                                    Text(card.punches[index].reason)
                                }
                            } else {
                                Image(systemName: hasPunch(index: index) ? "x.circle.fill" : "circle" )
                                    .imageScale(.small)
                            }
                        }
                    }
                }
            }
        }
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
        
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                VStack(alignment: .leading) {
                    Text(card.title)
                        .font(.title)
                        .lineLimit(1)
                    
                    Text("\(card.punches.count) punched / \(card.capacity) total")
                        .font(.caption)
                        .lineLimit(1)
                }
                
                Spacer()
                                
                PunchesGrid(card: card, numCols: 10, includeReasons: false)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

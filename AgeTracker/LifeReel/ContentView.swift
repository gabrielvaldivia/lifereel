import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PersonViewModel
    @State private var showingAddPerson = false
    @State private var navigationPath = NavigationPath()
    @State private var selectedPerson: Person?
    @State private var showOnboarding = false
    @State private var onboardingStep = 0
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding, viewModel: viewModel)
            } else {
                NavigationStack(path: $viewModel.navigationPath) {
                    ZStack {
                        if viewModel.people.isEmpty {
                            VStack {
                                Spacer()
                                addPersonButton
                                Spacer()
                            }
                        } else {
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(viewModel.people, id: \.id) { person in
                                        NavigationLink(value: person) {
                                            PersonGridItem(person: person)
                                        }
                                    }
                                    addPersonButton
                                }
                                .padding()
                            }
                        }
                    }
                    .navigationTitle("People")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("People")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: SettingsView(viewModel: viewModel, onShowOnboarding: {
                                showOnboarding = true
                            })) {
                                Image(systemName: "slider.vertical.3")
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .navigationDestination(for: Person.self) { person in
                        PersonDetailView(person: viewModel.bindingForPerson(person), viewModel: viewModel)
                    }
                    .sheet(isPresented: $showingAddPerson) {
                        NavigationView {
                            AddPersonView(
                                viewModel: viewModel,
                                isPresented: $showingAddPerson,
                                onboardingMode: false,
                                currentStep: .constant(1)
                            )
                        }
                    }
                }
                .environmentObject(viewModel)
            }
        }
        .onAppear {
            if viewModel.people.isEmpty && !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                showOnboarding = true
            } else if let lastOpenedPersonId = viewModel.lastOpenedPersonId,
                      let lastOpenedPerson = viewModel.people.first(where: { $0.id == lastOpenedPersonId }) {
                viewModel.navigationPath.append(lastOpenedPerson)
            } else if !viewModel.people.isEmpty {
                // If there are people but no last opened person, show the first person
                viewModel.navigationPath.append(viewModel.people[0])
            }
        }
        .onChange(of: viewModel.people.count) { _, newCount in
            if newCount > 0 && showOnboarding {
                showOnboarding = false
            }
        }
        .onChange(of: viewModel.people.count) { oldCount, newCount in
            if oldCount > newCount {
                // A person was deleted, pop to root
                viewModel.navigationPath.removeLast(viewModel.navigationPath.count)
            }
        }
    }
    
    private var addPersonButton: some View {
        Button(action: { showingAddPerson = true }) {
            VStack {
                Image(systemName: "plus")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .frame(width: 100, height: 100)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                Text("Add Someone")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct PersonGridItem: View {
    let person: Person
    
    var body: some View {
        VStack {
            if let latestPhoto = person.photos.sorted(by: { $0.dateTaken > $1.dateTaken }).first,
               let uiImage = latestPhoto.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
            }
            
            Text(person.name)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.primary)
        }
    }
}

struct WelcomeView: View {
    @Binding var showingAddPerson: Bool
    
    var body: some View {
        VStack {
            Text("Add someone to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { showingAddPerson = true }) {
                Text("Add Someone")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: PersonViewModel())
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: PersonViewModel
    @State private var showingDeleteConfirmation = false
    var onShowOnboarding: () -> Void

    var body: some View {
        List {
            // New section for Twitter link
            Section(header: Text("Support")) {
                Link(destination: URL(string: "https://x.com/gabrielvaldivia")!) {
                    HStack {
                        Text("Follow on Twitter")
                    }
                }
            }
            
            // New section for onboarding
            Section(header: Text("App Tour")) {
                Button("Replay Onboarding") {
                    onShowOnboarding()
                }
            }
            
            // Existing delete all data section
            Section(header: Text("Danger Zone")) {
                Button("Delete All Data") {
                    showingDeleteConfirmation = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Settings")
        .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteAllData()
            }
        } message: {
            Text("Are you sure you want to delete all data? This action cannot be undone.")
        }
    }
}
//
//  PersonDetailView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Photos

// Main view struct
struct PersonDetailView: View {
    // State and observed properties
    @State private var person: Person
    @ObservedObject var viewModel: PersonViewModel
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    @State private var imageMeta: [String: Any]?
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var currentPhotoIndex = 0
    @State private var latestPhotoIndex = 0 // New state variable
    @State private var lastFeedbackDate: Date?
    let impact = UIImpactFeedbackGenerator(style: .light)
    @State private var selectedView = 0 // 0 for All, 1 for Years
    @State private var showingBulkImport = false // New state variable
    @State private var showingSettings = false // New state variable

    // Initializer
    init(person: Person, viewModel: PersonViewModel) {
        _person = State(initialValue: person)
        self.viewModel = viewModel
        let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
        _latestPhotoIndex = State(initialValue: sortedPhotos.count - 1)
        _currentPhotoIndex = State(initialValue: sortedPhotos.count - 1)
    }
    
    // Main body of the view
    var body: some View {
        VStack {
            // Segmented control for view selection
            Picker("View", selection: $selectedView) {
                Text("All").tag(0)
                Text("Years").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            // Conditional view based on selection
            if selectedView == 0 {
                allPhotosView
            } else {
                yearsView
            }
        }
        // Navigation and toolbar setup
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(person.name).font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                    Menu {
                        Button(action: { 
                            showingImagePicker = true 
                        }) {
                            Label("Add Photo", systemImage: "camera")
                        }
                        Button(action: {
                            showingBulkImport = true
                        }) {
                            Label("Bulk Import", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: CustomBackButton())
        // Sheet presentation for image picker
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage, imageMeta: $imageMeta, isPresented: $showingImagePicker)
        }
        // Sheet presentation for bulk import
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView(viewModel: viewModel, person: $person, onImportComplete: { albumIdentifier in
                if let albumIdentifier = albumIdentifier {
                    person.syncedAlbumIdentifier = albumIdentifier
                } else {
                    person.syncedAlbumIdentifier = nil
                }
                viewModel.updatePerson(person)
            })
        }
        // Sheet presentation for settings
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                PersonSettingsView(viewModel: viewModel, person: $person)
            }
        }
        // Image selection handler
        .onChange(of: inputImage) { newImage in
            if let newImage = newImage {
                print("Image selected: \(newImage)")
                loadImage()
            } else {
                print("No image selected")
            }
        }
        // View appearance handler
        .onAppear {
            if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
                person = updatedPerson
                let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
                latestPhotoIndex = sortedPhotos.count - 1
                currentPhotoIndex = latestPhotoIndex
            }
        }
        // Delete photo alert
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Photo"),
                message: Text("Are you sure you want to delete this photo?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let photoToDelete = photoToDelete {
                        deletePhoto(photoToDelete)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // All photos view
    private var allPhotosView: some View {
        GeometryReader { geometry in
            VStack {
                if !person.photos.isEmpty {
                    let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
                    let safeIndex = min(max(0, currentPhotoIndex), sortedPhotos.count - 1)
                    
                    if let image = sortedPhotos[safeIndex].image {
                        Spacer()
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: geometry.size.height * 0.6)
                            .onTapGesture {
                                photoToDelete = sortedPhotos[safeIndex]
                                showingDeleteAlert = true
                            }
                        
                        VStack {
                            let age = viewModel.calculateAge(for: person, at: sortedPhotos[safeIndex].dateTaken)
                            Text(formatAge(years: age.years, months: age.months, days: age.days))
                                .font(.title3)
                            Text(formatDate(sortedPhotos[safeIndex].dateTaken))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        
                        Spacer()
                        
                        Slider(value: Binding(
                            get: { Double(safeIndex) },
                            set: { 
                                currentPhotoIndex = Int($0)
                                latestPhotoIndex = currentPhotoIndex
                            }
                        ), in: 0...Double(sortedPhotos.count - 1), step: 1)
                        .padding()
                        .onChange(of: currentPhotoIndex) { newValue in
                            if let lastFeedbackDate = lastFeedbackDate, Date().timeIntervalSince(lastFeedbackDate) < 0.5 {
                                return
                            }
                            lastFeedbackDate = Date()
                            impact.prepare()
                            impact.impactOccurred()
                        }
                    } else {
                        Text("Failed to load image")
                    }
                } else {
                    Text("No photos available")
                }
            }
        }
        .onAppear {
            currentPhotoIndex = min(latestPhotoIndex, person.photos.count - 1)
        }
    }

    // Years view
    private var yearsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupPhotosByAge(), id: \.0) { section, photos in
                    VStack(alignment: .leading) {
                        Text(section)
                            .font(.headline)
                            .padding(.leading)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                            ForEach(Array(photos.prefix(6).enumerated()), id: \.element.id) { index, photo in
                                if index < 5 || photos.count == 6 {
                                    photoThumbnail(photo)
                                } else {
                                    remainingPhotosCount(photos.count - 5)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // Helper view for photo thumbnail
    private func photoThumbnail(_ photo: Photo) -> some View {
        Group {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Color.gray
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // Helper view for remaining photos count
    private func remainingPhotosCount(_ count: Int) -> some View {
        ZStack {
            Color.gray.opacity(0.3)
            Text("+\(count)")
                .font(.title2)
                .foregroundColor(.white)
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // Function to group photos by age
    private func groupPhotosByAge() -> [(String, [Photo])] {
        let calendar = Calendar.current
        let sortedPhotos = person.photos.sorted(by: { $0.dateTaken > $1.dateTaken })
        var groupedPhotos: [(String, [Photo])] = []

        for photo in sortedPhotos {
            let components = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: photo.dateTaken)
            let years = components.year ?? 0
            let months = components.month ?? 0

            let sectionTitle: String
            if years == 0 {
                switch months {
                case 0:
                    sectionTitle = "Birth Month"
                case 1...11:
                    sectionTitle = "\(months) Month\(months == 1 ? "" : "s")"
                default:
                    sectionTitle = "1 Year"
                }
            } else {
                sectionTitle = "\(years) Year\(years == 1 ? "" : "s")"
            }

            if let index = groupedPhotos.firstIndex(where: { $0.0 == sectionTitle }) {
                groupedPhotos[index].1.append(photo)
            } else {
                groupedPhotos.append((sectionTitle, [photo]))
            }
        }

        return groupedPhotos.sorted { (group1, group2) -> Bool in
            let order = ["Birth Month"] + (1...11).map { "\($0) Month\($0 == 1 ? "" : "s")" }
            if let index1 = order.firstIndex(of: group1.0), let index2 = order.firstIndex(of: group2.0) {
                return index1 > index2
            } else if order.contains(group1.0) {
                return false
            } else if order.contains(group2.0) {
                return true
            } else {
                // For year sections, sort in descending order
                return group1.0 > group2.0
            }
        }
    }
    
    // Image loading function
    func loadImage() {
        guard let inputImage = inputImage else { 
            print("No image to load")
            return 
        }
        print("Full metadata: \(String(describing: imageMeta))")
        let dateTaken = extractDateTaken(from: imageMeta) ?? Date()
        print("Extracted date taken: \(dateTaken)")
        print("Adding photo with date: \(dateTaken)")
        viewModel.addPhoto(to: &person, image: inputImage, dateTaken: dateTaken)
        // The local person state is now updated automatically
        if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
            person = updatedPerson
            // Find the index of the newly added photo
            let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
            if let newPhotoIndex = sortedPhotos.firstIndex(where: { $0.dateTaken == dateTaken }) {
                latestPhotoIndex = newPhotoIndex
                currentPhotoIndex = newPhotoIndex
            }
        }
    }

    // Function to extract date taken from metadata
    func extractDateTaken(from metadata: [String: Any]?) -> Date? {
        print("Full metadata: \(String(describing: metadata))")
        if let dateTimeOriginal = metadata?["DateTimeOriginal"] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            if let date = dateFormatter.date(from: dateTimeOriginal) {
                print("Extracted date: \(date)")
                return date
            }
        }
        print("Failed to extract date, using current date")
        return Date()
    }

    // Function to delete a photo
    func deletePhoto(_ photo: Photo) {
        if let index = person.photos.firstIndex(where: { $0.id == photo.id }) {
            person.photos.remove(at: index)
            viewModel.updatePerson(person)
        }
    }
    
    // Helper function to format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Helper function to format age
    private func formatAge(years: Int, months: Int, days: Int) -> String {
        var components: [String] = []
        
        if years > 0 {
            components.append("\(years) year\(years == 1 ? "" : "s")")
        }
        if months > 0 {
            components.append("\(months) month\(months == 1 ? "" : "s")")
        }
        if days > 0 || (years == 0 && months == 0) {
            if years == 0 && months == 0 && days == 0 {
                components.append("Newborn")
            } else {
                components.append("\(days) day\(days == 1 ? "" : "s")")
            }
        }
        
        return components.joined(separator: ", ")
    }
}

struct CustomBackButton: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left")
                .foregroundColor(.blue)
        }
    }
}
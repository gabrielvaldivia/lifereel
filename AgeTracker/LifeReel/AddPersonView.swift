//
//  AddPersonView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import SwiftUI
import PhotosUI

struct AddPersonView: View {
    @ObservedObject var viewModel: PersonViewModel
    @State private var name = ""
    @State private var dateOfBirth: Date?
    @State private var selectedAssets: [PHAsset] = []
    @State private var showImagePicker = false
    @State private var imageMeta: [String: Any]?
    @State private var showDatePickerSheet = false
    @State private var showAgeText = false
    @Environment(\.presentationMode) var presentationMode
    
    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    TextField("Name", text: $name)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                    
                    HStack {
                        Text("Date of Birth")
                        Spacer()
                        if let dateOfBirth = dateOfBirth {
                            Text(dateOfBirth, formatter: dateFormatter)
                                .foregroundColor(.gray)
                        } else {
                            Text("Select Date")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showDatePickerSheet = true
                    }
                    
                    // Photo selection grid
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(selectedAssets, id: \.localIdentifier) { asset in
                            AssetThumbnail(asset: asset)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        Button(action: {
                            showImagePicker = true
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    if showAgeText, let dob = dateOfBirth, !name.isEmpty, !selectedAssets.isEmpty {
                        let photoDate = extractDateTaken(from: imageMeta) ?? Date()
                        Text(calculateAge(for: dob, at: photoDate, name: name))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer(minLength: 300)
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .ignoresSafeArea(.keyboard)
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveNewPerson()
                }
                .disabled(selectedAssets.isEmpty || name.isEmpty || dateOfBirth == nil)
            )
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            loadImages(from: selectedAssets)
        }) {
            ImagePicker(selectedAssets: $selectedAssets, isPresented: $showImagePicker)
        }
        .sheet(isPresented: $showDatePickerSheet) {
            BirthDaySheet(dateOfBirth: Binding(
                get: { self.dateOfBirth ?? Date() },
                set: { 
                    self.dateOfBirth = $0
                    self.showAgeText = true
                }
            ), isPresented: $showDatePickerSheet)
                .presentationDetents([.height(300)])
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private func extractDateTaken(from metadata: [String: Any]?) -> Date? {
        if let dateTimeOriginal = metadata?["DateTimeOriginal"] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            return dateFormatter.date(from: dateTimeOriginal)
        }
        return nil
    }
    
    private func calculateAge(for dob: Date, at photoDate: Date, name: String) -> String {
        let calendar = Calendar.current
        
        if photoDate >= dob {
            let components = calendar.dateComponents([.year, .month, .day], from: dob, to: photoDate)
            let years = components.year ?? 0
            let months = components.month ?? 0
            let days = components.day ?? 0
            
            var ageComponents: [String] = []
            if years > 0 { ageComponents.append("\(years) year\(years == 1 ? "" : "s")") }
            if months > 0 { ageComponents.append("\(months) month\(months == 1 ? "" : "s")") }
            if days > 0 || ageComponents.isEmpty { ageComponents.append("\(days) day\(days == 1 ? "" : "s")") }
            
            return "\(name) is \(ageComponents.joined(separator: ", ")) old"
        } else {
            let weeksBeforeBirth = calendar.dateComponents([.weekOfYear], from: photoDate, to: dob).weekOfYear ?? 0
            let pregnancyWeek = max(40 - weeksBeforeBirth, 0)
            
            if pregnancyWeek > 0 {
                return "\(name)'s mom is \(pregnancyWeek) week\(pregnancyWeek == 1 ? "" : "s") pregnant"
            } else {
                return "\(name)'s mom is not yet pregnant"
            }
        }
    }
    
    private func loadImages(from assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        
        let asset = assets[0] // For now, we'll just use the first selected asset
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
            if let image = image {
                self.imageMeta = info as? [String: Any]
            }
        }
    }
    
    private func saveNewPerson() {
        guard let dateOfBirth = dateOfBirth else { return }
        
        print("Selected assets count: \(selectedAssets.count)")
        
        let group = DispatchGroup()
        var newPhotos: [Photo] = []
        
        for (index, asset) in selectedAssets.enumerated() {
            group.enter()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
                defer { group.leave() }
                if let image = image {
                    let dateTaken = asset.creationDate ?? Date()
                    let newPhoto = Photo(image: image, dateTaken: dateTaken)
                    newPhotos.append(newPhoto)
                    print("Added photo \(index + 1) with date: \(dateTaken)")
                } else {
                    print("Failed to get image for asset \(index + 1)")
                }
            }
        }
        
        group.notify(queue: .main) {
            print("All photos processed. Total new photos: \(newPhotos.count)")
            var newPerson = Person(name: self.name, dateOfBirth: dateOfBirth)
            newPerson.photos = newPhotos
            self.viewModel.updatePerson(newPerson)
            print("New person created with \(newPerson.photos.count) photos")
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct AssetThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray
            }
        }
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.isSynchronous = true
        manager.requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFill, options: option) { result, info in
            if let result = result {
                image = result
            }
        }
    }
}
//
//  GridView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/12/24.
//

import SwiftUI
import Photos

struct GridView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    @Binding var currentScrollPosition: String?
    var openImagePickerForMoment: (String) -> Void
    var deletePhoto: (Photo) -> Void
    var scrollToSection: (String) -> Void

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 16
            let itemWidth = (geometry.size.width - 40 - spacing * 2) / 3
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3), spacing: spacing) {
                    ForEach(PhotoUtils.sortedGroupedPhotosForAllIncludingEmpty(person: person, viewModel: viewModel).filter { !person.hideEmptyStacks || !$0.1.isEmpty }, id: \.0) { section, photos in
                        if photos.isEmpty {
                            EmptyStackView(section: section, width: itemWidth) {
                                openImagePickerForMoment(section)
                                scrollToSection(section)
                            }
                        } else {
                            NavigationLink(destination: StackDetailView(sectionTitle: section, photos: photos, onDelete: deletePhoto, person: person, viewModel: viewModel)) {
                                StackTileView(section: section, photos: photos, width: itemWidth)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 80)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                updateScrollPosition(value)
            }
        }
    }

    private func updateScrollPosition(_ value: CGPoint) {
        let sections = PhotoUtils.sortedGroupedPhotosForAllIncludingEmpty(person: person, viewModel: viewModel).map { $0.0 }
        if let index = sections.firstIndex(where: { section in
            let sectionY = value.y + UIScreen.main.bounds.height / 2
            return sectionY >= 0 && sectionY <= UIScreen.main.bounds.height
        }) {
            currentScrollPosition = sections[index]
        }
    }
}

struct EmptyStackView: View {
    let section: String
    let width: CGFloat
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                    
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: width, height: width)
            
            Text(section)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: width)
        }
    }
}

struct StackTileView: View {
    let section: String
    let photos: [Photo]
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let firstPhoto = photos.first, let image = firstPhoto.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        if photos.count > 2 {
                            Text("\(photos.count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                                .padding(4)
                        }
                    }
                }
            }
            .frame(width: width, height: width)
            .cornerRadius(8)
            
            Text(section)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: width)
        }
    }
}
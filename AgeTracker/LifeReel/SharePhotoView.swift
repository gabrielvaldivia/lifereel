import Foundation
import SwiftUI

struct SharePhotoView: View {
    let image: UIImage
    let name: String
    let age: String
    @Binding var isShareSheetPresented: Bool
    @Binding var activityItems: [Any]
    @State private var showingPolaroidSheet = false
    @State private var selectedTemplate = 0
    @State private var renderedImage: UIImage?
    @State private var isPreparingImage = false
    @State private var titleOption = TitleOption.name
    @State private var subtitleOption = TitleOption.age
    @State private var showAppIcon = true
    @State private var isRendering = false
    @State private var aspectRatio: AspectRatio = .original
    @Environment(\.dismiss) private var dismiss
    @State private var templateHeight: CGFloat = 520 // Default height

    enum TitleOption: String, CaseIterable, CustomStringConvertible {
        case none = "None"
        case name = "Name"
        case age = "Age"
        case date = "Date"
        
        var description: String { self.rawValue }
    }

    enum AspectRatio: String, CaseIterable, CustomStringConvertible {
        case original = "Original"
        case square = "Square"
        
        var description: String { self.rawValue }
    }

    init(image: UIImage, name: String, age: String, isShareSheetPresented: Binding<Bool>, activityItems: Binding<[Any]>) {
        self.image = image
        self.name = name
        self.age = age
        self._isShareSheetPresented = isShareSheetPresented
        self._activityItems = activityItems
        
        // Customize UIPageControl appearance
        UIPageControl.appearance().currentPageIndicatorTintColor = .secondaryLabel
        UIPageControl.appearance().pageIndicatorTintColor = .tertiaryLabel
    }

    private var calculatedTemplateHeight: CGFloat {
        let baseHeight: CGFloat = 380 // Base height for square aspect ratio
        if aspectRatio == .original {
            let imageAspectRatio = image.size.height / image.size.width
            return baseHeight + (280 * (imageAspectRatio - 1))
        }
        return baseHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .frame(height: 52)
            
            // Scrollable content
            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        Spacer(minLength: 20)
                        
                        // Template views
                        TabView(selection: $selectedTemplate) {
                            LightTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
                                .tag(0)
                            DarkTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
                                .tag(1)
                            OverlayTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
                                .tag(2)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(width: geometry.size.width, height: geometry.size.height - 100)
                        
                        // Custom page indicator
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(selectedTemplate == index ? Color.secondary : Color.secondary.opacity(0.5))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 20)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            
            // Controls
            controlsView
                .frame(height: 60)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .navigationBarHidden(true) 
        .sheet(isPresented: $showingPolaroidSheet) {
            if let uiImage = renderedImage {
                ActivityViewController(activityItems: [uiImage])
            }
        }
    }

    // Header View
    private var headerView: some View {
        HStack {
            cancelButton
            Spacer()
            Text("Pick template")
                .font(.headline)
            Spacer()
            shareButton
        }
        .padding(.horizontal)
    }

    // Controls View
    private var controlsView: some View {
        VStack {
            Divider()
            HStack(spacing: 40) {
                SimplifiedCustomizationButton(
                    icon: "textformat",
                    title: "Title",
                    options: TitleOption.allCases,
                    selection: $titleOption
                )

                SimplifiedCustomizationButton(
                    icon: "text.alignleft",
                    title: "Subtitle",
                    options: availableSubtitleOptions,
                    selection: $subtitleOption
                )

                SimplifiedCustomizationButton(
                    icon: "aspectratio",
                    title: "Aspect Ratio",
                    options: AspectRatio.allCases,
                    selection: $aspectRatio
                )

                // App Icon toggle
                VStack(spacing: 8) {
                    Button(action: { showAppIcon.toggle() }) {
                        VStack(spacing: 8) {
                            Image(systemName: showAppIcon ? "app.badge.checkmark" : "app")
                                .font(.system(size: 24))
                                .frame(height: 24)
                            Text("App Icon")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                .frame(height: 50)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 8)
            
        }
        .background(Color(UIColor.systemBackground))
    }

    private var availableSubtitleOptions: [TitleOption] {
        TitleOption.allCases.filter { $0 != titleOption || $0 == .none }
    }

    private var shareButton: some View {
        Button(action: {
            Task { @MainActor in
                await prepareSharePhoto()
            }
        }) {
            if isPreparingImage {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else {
                Text("Share")
            }
        }
        .disabled(isPreparingImage)
    }

    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
    }

    @MainActor
    private func prepareSharePhoto() async {
        guard !isPreparingImage else { return }
        isPreparingImage = true
        isRendering = true

        let baseWidth: CGFloat = 1080 // High-resolution base width
        let padding: CGFloat = baseWidth * 0.05 // 5% padding
        let bottomAreaHeight: CGFloat = baseWidth * 0.15 // Reduced height for text and icon area

        // Calculate the height based on the aspect ratio
        let imageHeight: CGFloat
        if aspectRatio == .square {
            imageHeight = baseWidth - (padding * 2)
        } else {
            let imageAspectRatio = image.size.height / image.size.width
            imageHeight = (baseWidth - (padding * 2)) * imageAspectRatio
        }

        let baseHeight: CGFloat = imageHeight + (padding * 2) + bottomAreaHeight

        UIGraphicsBeginImageContextWithOptions(CGSize(width: baseWidth, height: baseHeight), false, 1.0)
        defer { UIGraphicsEndImageContext() }

        // Handle different templates
        switch selectedTemplate {
        case 0, 1: // Light and Dark templates
            renderStandardTemplate(baseWidth: baseWidth, baseHeight: baseHeight, padding: padding, imageHeight: imageHeight)
        case 2: // Overlay template
            renderOverlayTemplate(baseWidth: baseWidth, baseHeight: baseHeight, padding: padding, imageHeight: imageHeight)
        default:
            break
        }

        if let finalImage = UIGraphicsGetImageFromCurrentImageContext() {
            renderedImage = finalImage
            showingPolaroidSheet = true
        }

        isRendering = false
        isPreparingImage = false
    }

    private func renderStandardTemplate(baseWidth: CGFloat, baseHeight: CGFloat, padding: CGFloat, imageHeight: CGFloat) {
        // Draw background
        let backgroundColor: UIColor = selectedTemplate == 1 ? .black : .white
        backgroundColor.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: baseWidth, height: baseHeight))

        // Calculate image size and position
        let imageWidth = baseWidth - (padding * 2)
        let imageRect = CGRect(x: padding, y: padding, width: imageWidth, height: imageHeight)

        // Draw image
        if aspectRatio == .square {
            // For square aspect ratio, crop the image to fit
            if let cgImage = image.cgImage {
                let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
                let sourceSide = min(sourceSize.width, sourceSize.height)
                let sourceX = (sourceSize.width - sourceSide) / 2
                let sourceY = (sourceSize.height - sourceSide) / 2
                let sourceRect = CGRect(x: sourceX, y: sourceY, width: sourceSide, height: sourceSide)
                
                if let croppedImage = cgImage.cropping(to: sourceRect) {
                    UIImage(cgImage: croppedImage).draw(in: imageRect)
                }
            }
        } else {
            // For other aspect ratios, draw normally
            image.draw(in: imageRect)
        }

        // Calculate text position
        let textY = imageRect.maxY + (padding * 0.5)

        // Draw text and app icon
        drawTextAndIcon(at: CGPoint(x: padding, y: textY), maxWidth: imageWidth, baseWidth: baseWidth, baseHeight: baseHeight, padding: padding)
    }

    private func renderOverlayTemplate(baseWidth: CGFloat, baseHeight: CGFloat, padding: CGFloat, imageHeight: CGFloat) {
        let drawingRect = CGRect(x: 0, y: 0, width: baseWidth, height: baseHeight)

        // Draw image
        let imageSize = image.size
        let imageAspect = imageSize.height / imageSize.width
        let rectAspect = drawingRect.height / drawingRect.width
        
        let drawRect: CGRect
        if imageAspect > rectAspect {
            // Image is taller, crop top and bottom
            let newHeight = drawingRect.width * imageAspect
            let yOffset = (newHeight - drawingRect.height) / 2
            drawRect = CGRect(x: 0, y: -yOffset, width: drawingRect.width, height: newHeight)
        } else {
            // Image is wider, crop sides
            let newWidth = drawingRect.height / imageAspect
            let xOffset = (newWidth - drawingRect.width) / 2
            drawRect = CGRect(x: -xOffset, y: 0, width: newWidth, height: drawingRect.height)
        }
        
        // Create a clipping path to ensure the image doesn't draw outside the bounds
        let path = UIBezierPath(rect: drawingRect)
        path.addClip()
        
        image.draw(in: drawRect)

        // Add overlay gradient
        let context = UIGraphicsGetCurrentContext()!
        let colors = [UIColor.black.withAlphaComponent(0.5).cgColor, UIColor.clear.cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: drawingRect.maxY), end: CGPoint(x: 0, y: drawingRect.maxY - drawingRect.height * 0.3), options: [])

        // Draw text and app icon
        let textY = drawingRect.maxY - padding - (baseWidth * 0.05) - (baseWidth * 0.035) - 5
        drawTextAndIcon(at: CGPoint(x: padding, y: textY), maxWidth: baseWidth - (padding * 2), baseWidth: baseWidth, baseHeight: baseHeight, padding: padding)
    }

    private func drawTextAndIcon(at point: CGPoint, maxWidth: CGFloat, baseWidth: CGFloat, baseHeight: CGFloat, padding: CGFloat) {
        let titleFont = UIFont.systemFont(ofSize: baseWidth * 0.05, weight: .bold)
        let subtitleFont = UIFont.systemFont(ofSize: baseWidth * 0.04)
        let textColor: UIColor = selectedTemplate == 0 ? .black : .white

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: textColor
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: textColor.withAlphaComponent(0.7)
        ]

        let titleText = NSAttributedString(string: getTitleText(), attributes: titleAttributes)
        let subtitleText = NSAttributedString(string: getSubtitleText(), attributes: subtitleAttributes)

        // Calculate text sizes
        let titleSize = titleText.size()
        let subtitleSize = subtitleText.size()

        // Draw text in VStack
        titleText.draw(at: point)
        subtitleText.draw(at: CGPoint(x: point.x, y: point.y + titleSize.height + 5))

        if showAppIcon, let appIcon = UIImage(named: "AppIcon") {
            let iconSize = baseWidth * 0.11
            let iconX = baseWidth - iconSize - padding
            let iconY = point.y + (max(titleSize.height + subtitleSize.height, iconSize) - iconSize) / 2
            appIcon.draw(in: CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
        }
    }

    private func getTitleText() -> String {
        switch titleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }

    private func getSubtitleText() -> String {
        switch subtitleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct LightTemplateView: View {
    let image: UIImage
    let name: String
    let age: String
    let titleOption: SharePhotoView.TitleOption
    let subtitleOption: SharePhotoView.TitleOption
    let showAppIcon: Bool
    let isRendering: Bool
    let aspectRatio: SharePhotoView.AspectRatio
    @State private var textAreaHeight: CGFloat = 60
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 40 
            let templateHeight = calculateTemplateHeight(for: availableWidth)
            
            VStack(spacing: 0) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: availableWidth - 40, height: templateHeight - textAreaHeight - 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .clipped()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if !titleText.isEmpty {
                            Text(titleText)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                        }
                        if !subtitleText.isEmpty {
                            Text(subtitleText)
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.8))
                        }
                    }
                    Spacer()
                    if showAppIcon {
                        Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 10)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
                })
            }
            .padding(20)
            .frame(width: availableWidth, height: templateHeight)
            .background(Color.white)
            .cornerRadius(isRendering ? 0 : 20)
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .onPreferenceChange(ViewHeightKey.self) { height in
                self.textAreaHeight = height
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var titleText: String {
        switch titleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }
    
    private var subtitleText: String {
        switch subtitleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func calculateTemplateHeight(for width: CGFloat) -> CGFloat {
        switch aspectRatio {
        case .original:
            return width * (image.size.height / image.size.width)
        case .square:
            return width
        }
    }
}

struct DarkTemplateView: View {
    let image: UIImage
    let name: String
    let age: String
    let titleOption: SharePhotoView.TitleOption
    let subtitleOption: SharePhotoView.TitleOption
    let showAppIcon: Bool
    let isRendering: Bool
    let aspectRatio: SharePhotoView.AspectRatio
    @State private var textAreaHeight: CGFloat = 60
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 40 
            let templateHeight = calculateTemplateHeight(for: availableWidth)
            
            VStack(spacing: 0) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: availableWidth - 40, height: templateHeight - textAreaHeight - 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .clipped()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if !titleText.isEmpty {
                            Text(titleText)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        if !subtitleText.isEmpty {
                            Text(subtitleText)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    Spacer()
                    if showAppIcon {
                        Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 10)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
                })
            }
            .padding(20)
            .frame(width: availableWidth, height: templateHeight)
            .background(Color.black)
            .cornerRadius(isRendering ? 0 : 20)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .onPreferenceChange(ViewHeightKey.self) { height in
                self.textAreaHeight = height
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var titleText: String {
        switch titleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }
    
    private var subtitleText: String {
        switch subtitleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func calculateTemplateHeight(for width: CGFloat) -> CGFloat {
        switch aspectRatio {
        case .original:
            return width * (image.size.height / image.size.width)
        case .square:
            return width
        }
    }
}

struct OverlayTemplateView: View {
    let image: UIImage
    let name: String
    let age: String
    let titleOption: SharePhotoView.TitleOption
    let subtitleOption: SharePhotoView.TitleOption
    let showAppIcon: Bool
    let isRendering: Bool
    let aspectRatio: SharePhotoView.AspectRatio
    @State private var textAreaHeight: CGFloat = 60
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 40
            let templateHeight = calculateTemplateHeight(for: availableWidth)
            
            ZStack(alignment: .bottom) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: availableWidth, height: templateHeight)
                    .clipped()
                
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.5), Color.black.opacity(0)]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: templateHeight * 0.4)
                
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            if !titleText.isEmpty {
                                Text(titleText)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            if !subtitleText.isEmpty {
                                Text(subtitleText)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .opacity(0.8)
                            }
                        }
                        Spacer()
                        if showAppIcon {
                            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ViewHeightKey.self, value: geo.size.height)
                    })
                }
            }
            .frame(width: availableWidth, height: templateHeight)
            .cornerRadius(isRendering ? 0 : 20)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .onPreferenceChange(ViewHeightKey.self) { height in
                self.textAreaHeight = height
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var titleText: String {
        switch titleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }
    
    private var subtitleText: String {
        switch subtitleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func calculateTemplateHeight(for width: CGFloat) -> CGFloat {
        switch aspectRatio {
        case .original:
            let imageAspectRatio = image.size.height / image.size.width
            return width * imageAspectRatio
        case .square:
            return width
        }
    }
}

struct SimplifiedCustomizationButton<T: Hashable & CustomStringConvertible>: View {
    let icon: String
    let title: String
    let options: [T]
    @Binding var selection: T

    var body: some View {
        Menu {
            Picker(selection: $selection, label: EmptyView()) {
                ForEach(options, id: \.self) { option in
                    Text(option.description).tag(option)
                }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
        }
        .foregroundColor(.primary)
    }
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

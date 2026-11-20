import SwiftUI
import ImageIO

struct PhotoCropSelection: Identifiable {
    let id = UUID()
    let data: Data
}

struct PhotoCropView: View {
    let data: Data
    var completion: (Data?) -> Void
    @State private var zoom: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var previousOffset = CGSize.zero
    @State private var previousZoom: CGFloat = 1
    @State private var error: String?

    private var image: UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Breng de vogel in beeld").font(FieldGuideTheme.sans(24, relativeTo: .title2))
                if let image {
                    GeometryReader { geometry in
                        let side = geometry.size.width
                        let base = side / min(image.size.width, image.size.height)
                        let width = image.size.width * base * zoom
                        let height = image.size.height * base * zoom
                        Image(uiImage: image).resizable().frame(width: width, height: height)
                            .offset(x: offset.width, y: offset.height)
                            .frame(width: side, height: side).clipped()
                            .contentShape(Rectangle())
                            .gesture(DragGesture().onChanged { value in
                                offset = bounded(CGSize(width: previousOffset.width + value.translation.width,
                                    height: previousOffset.height + value.translation.height), width: width, height: height, side: side)
                            }.onEnded { _ in previousOffset = offset })
                            .simultaneousGesture(MagnificationGesture().onChanged { value in
                                zoom = min(5, max(1, previousZoom * value))
                                offset = bounded(offset, width: image.size.width * base * zoom, height: image.size.height * base * zoom, side: side)
                            }.onEnded { _ in previousZoom = zoom; previousOffset = offset })
                            .accessibilityLabel("Vogeluitsnede. Gebruik de zoomknoppen of sleep de foto.")
                            .overlay(alignment: .bottomTrailing) {
                                HStack {
                                    Button("Uitzoomen", systemImage: "minus.magnifyingglass") { changeZoom(-0.25, image: image, side: side) }
                                    Button("Inzoomen", systemImage: "plus.magnifyingglass") { changeZoom(0.25, image: image, side: side) }
                                }.labelStyle(.iconOnly).buttonStyle(.borderedProminent).padding(8)
                            }
                            .overlay(alignment: .topTrailing) {
                                Button("Gebruik uitsnede") {
                                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                                    let output = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024), format: format).image { _ in
                                        let scale = 1024 / side
                                        image.draw(in: CGRect(x: ((side - width) / 2 + offset.width) * scale,
                                            y: ((side - height) / 2 + offset.height) * scale, width: width * scale, height: height * scale))
                                    }
                                    if let bytes = output.jpegData(compressionQuality: 0.95) { completion(bytes) }
                                    else { error = "De uitsnede kon niet worden gemaakt." }
                                }.buttonStyle(.borderedProminent).padding(8)
                            }
                    }.aspectRatio(1, contentMode: .fit)
                    Text("Sleep en zoom zodat de vogel duidelijk zichtbaar is.").font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
                } else { Text("Deze foto kon niet worden geopend.") }
                if let error { Text(error) }
                Spacer()
            }.padding(20).background(FieldGuideTheme.ivory)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { completion(nil) } } }
        }
    }
    private func bounded(_ value: CGSize, width: CGFloat, height: CGFloat, side: CGFloat) -> CGSize {
        CGSize(width: min((width - side) / 2, max(-(width - side) / 2, value.width)),
               height: min((height - side) / 2, max(-(height - side) / 2, value.height)))
    }
    private func changeZoom(_ delta: CGFloat, image: UIImage, side: CGFloat) {
        zoom = min(5, max(1, zoom + delta)); previousZoom = zoom
        let base = side / min(image.size.width, image.size.height)
        offset = bounded(offset, width: image.size.width * base * zoom, height: image.size.height * base * zoom, side: side)
        previousOffset = offset
    }
}

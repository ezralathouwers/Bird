import SwiftUI
import ImageIO

struct PhotoCropSelection: Identifiable {
    let id = UUID()
    let data: Data
}

struct PhotoCropView: View {
    let data: Data
    @State private var location: PhotoLocationSelection?
    var completion: (Data?, PhotoLocationSelection?) -> Void
    @State private var showLocation = false
    @State private var previewSide: CGFloat = 1
    init(data: Data, location: PhotoLocationSelection? = nil, completion: @escaping (Data?, PhotoLocationSelection?) -> Void) {
        self.data = data; self.completion = completion; _location = State(initialValue: location)
    }
    @State private var zoom: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var previousOffset = CGSize.zero
    @State private var previousZoom: CGFloat = 1
    @State private var error: String?

    @State private var image: UIImage?
    @State private var imageLoaded = false
    private static func loadImage(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: "Foto ID") { completion(nil, location) }
            ScrollView {
                VStack(spacing: 16) {
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
                                .accessibilityLabel("Vogeluitsnede. Sleep of gebruik de zoomknoppen.")
                                .overlay(alignment: .bottomTrailing) {
                                    HStack(spacing: 8) {
                                        zoomButton(-0.25, image: image, side: side)
                                        zoomButton(0.25, image: image, side: side)
                                    }.padding(12)
                                }
                                .onAppear { previewSide = side }
                                .onChange(of: side) { _, value in previewSide = value }
                        }.aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 20))
                        Button(location == nil ? "Locatie toevoegen" : "Locatie bewerken") { showLocation = true }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(FieldGuideTheme.beige, in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
                        if let location { Text(location.name).font(FieldGuideTheme.sans(14)) }
                        Button("Identificeer vogel") { finish(image: image, side: previewSide) }
                            .frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(FieldGuideTheme.ivory)
                            .background(FieldGuideTheme.charcoal, in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
                    } else if !imageLoaded { ProgressView("Foto openen…") }
                    else { Text("Deze foto kon niet worden geopend.") }
                    if let error { Text(error) }
                }.padding(20)
            }
        }.foregroundStyle(FieldGuideTheme.charcoal).background(FieldGuideTheme.ivory.ignoresSafeArea())
            .task { if !imageLoaded { image = Self.loadImage(data); imageLoaded = true } }
            .sheet(isPresented: $showLocation) { PhotoLocationPicker(selection: location) { location = $0 } }
    }
    private func zoomButton(_ delta: CGFloat, image: UIImage, side: CGFloat) -> some View {
        Button { changeZoom(delta, image: image, side: side) } label: {
            PhotoZoomMark(plus: delta > 0).stroke(style: FieldGuideTheme.navigationStroke)
                .frame(width: 24, height: 24).frame(width: 44, height: 44)
                .foregroundStyle(FieldGuideTheme.charcoal).background(.white, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).accessibilityLabel(delta > 0 ? "Inzoomen" : "Uitzoomen")
    }
    private func finish(image: UIImage, side: CGFloat) {
        guard side > 0 else { return }
        let base = side / min(image.size.width, image.size.height)
        let width = image.size.width * base * zoom, height = image.size.height * base * zoom
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let output = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024), format: format).image { _ in
            let scale = 1024 / side
            image.draw(in: CGRect(x: ((side - width) / 2 + offset.width) * scale,
                y: ((side - height) / 2 + offset.height) * scale, width: width * scale, height: height * scale))
        }
        if let bytes = output.jpegData(compressionQuality: 0.95) { completion(bytes, location) }
        else { error = "De uitsnede kon niet worden gemaakt." }
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

private struct PhotoZoomMark: Shape {
    let plus: Bool
    func path(in rect: CGRect) -> Path {
        var path = FineSearchMark().path(in: rect)
        let sx = rect.width / 24, sy = rect.height / 24
        path.move(to: CGPoint(x: 5 * sx, y: 9.25 * sy)); path.addLine(to: CGPoint(x: 13.5 * sx, y: 9.25 * sy))
        if plus { path.move(to: CGPoint(x: 9.25 * sx, y: 5 * sy)); path.addLine(to: CGPoint(x: 9.25 * sx, y: 13.5 * sy)) }
        return path
    }
}

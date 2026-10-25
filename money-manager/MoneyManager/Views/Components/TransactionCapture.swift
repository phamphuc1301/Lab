import PhotosUI
import SwiftUI

enum CaptureAction: Identifiable {
    case camera, photos, manual
    var id: Self { self }
}

/// The "+" menu shown in toolbars: scan, import a photo, or type it in.
struct CaptureMenu: View {
    @Binding var action: CaptureAction?

    var body: some View {
        Menu {
            if DocumentCameraView.isSupported {
                Button { action = .camera } label: { Label("Scan receipt", systemImage: "doc.text.viewfinder") }
            }
            Button { action = .photos } label: { Label("Import from Photos", systemImage: "photo.on.rectangle") }
            Button { action = .manual } label: { Label("Add manually", systemImage: "square.and.pencil") }
        } label: {
            Label("Add", systemImage: "plus.circle.fill")
        }
    }
}

/// Presents the camera / photo picker, runs OCR, then opens a pre-filled editor
/// so the user can confirm the scanned values before the transaction is saved.
@MainActor
private struct TransactionCaptureModifier: ViewModifier {
    @Binding var action: CaptureAction?

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var scannedImage: UIImage?
    @State private var draft: TransactionDraft?
    @State private var isReading = false
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: action) { _, newValue in
                guard let newValue else { return }
                switch newValue {
                case .camera: showCamera = true
                case .photos: showPhotoPicker = true
                case .manual: draft = TransactionDraft()
                }
                action = nil
            }
            .fullScreenCover(isPresented: $showCamera, onDismiss: processScannedImage) {
                DocumentCameraView { images in
                    scannedImage = images.first
                    showCamera = false
                } onCancel: {
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await read(image)
                    } else {
                        errorMessage = "That photo couldn't be loaded."
                    }
                }
            }
            .sheet(item: $draft) { draft in
                TransactionEditorView(draft: draft)
            }
            .overlay {
                if isReading {
                    ProgressView("Reading receipt…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .alert("Couldn't scan receipt", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Enter manually") { draft = TransactionDraft() }
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private func processScannedImage() {
        guard let image = scannedImage else { return }
        scannedImage = nil
        Task { await read(image) }
    }

    private func read(_ image: UIImage) async {
        isReading = true
        defer { isReading = false }
        do {
            let lines = try await ReceiptTextRecognizer.recognize(image)
            let receipt = ReceiptParser().parse(lines: lines)
            draft = TransactionDraft(receipt: receipt, imageData: image.compressedJPEG())
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension View {
    func transactionCapture(action: Binding<CaptureAction?>) -> some View {
        modifier(TransactionCaptureModifier(action: action))
    }
}

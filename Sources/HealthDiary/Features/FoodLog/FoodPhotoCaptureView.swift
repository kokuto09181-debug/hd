import SwiftUI
import PhotosUI
import Vision
import CoreML

struct FoodPhotoCaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var capturedImage: UIImage? = nil
    @State private var recognizedFoodName: String = ""
    @State private var isRecognizing = false
    @State private var mealType: MealType = .dinner
    @State private var showingConfirm = false
    @State private var useCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                imageSection
                if capturedImage != nil {
                    recognitionResultSection
                }
                Spacer()
            }
            .padding()
            .navigationTitle("写真から記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $showingConfirm) {
                FoodLogAddFromPhotoView(
                    recognizedName: recognizedFoodName,
                    mealType: mealType,
                    onSave: { dismiss() }
                )
            }
        }
    }

    private var imageSection: some View {
        VStack(spacing: 16) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary)
                    .frame(height: 280)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("食事の写真を選択")
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("ライブラリ", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .onChange(of: selectedPhoto) { _, item in
                    loadPhoto(item)
                }

                Button {
                    useCamera = true
                } label: {
                    Label("カメラ", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var recognitionResultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isRecognizing {
                HStack {
                    ProgressView()
                    Text("料理を認識中...")
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("認識結果")
                        .font(.subheadline.bold())

                    TextField("料理名", text: $recognizedFoodName)
                        .textFieldStyle(.roundedBorder)

                    Picker("食事", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        showingConfirm = true
                    } label: {
                        Text("カロリーを確認して記録")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.tint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isRecognizing = true
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                capturedImage = image
                recognizedFoodName = await recognizeFood(in: image)
            }
            isRecognizing = false
        }
    }

    // Vision による食品認識（分類モデルがある場合に使用）
    private func recognizeFood(in image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let label = (request.results as? [VNClassificationObservation])?
                    .first(where: { $0.confidence > 0.3 })?.identifier ?? ""
                continuation.resume(returning: label)
            }
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}

// MARK: - Confirm & Save

struct FoodLogAddFromPhotoView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var recognizedName: String
    var mealType: MealType
    var onSave: () -> Void

    @State private var recipeName: String
    @State private var calories = ""
    @State private var servings = 1.0

    init(recognizedName: String, mealType: MealType, onSave: @escaping () -> Void) {
        self.recognizedName = recognizedName
        self.mealType = mealType
        self.onSave = onSave
        _recipeName = State(initialValue: recognizedName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("認識された料理") {
                    TextField("料理名", text: $recipeName)
                    HStack {
                        Text("カロリー（目安）")
                        Spacer()
                        TextField("kcal", text: $calories)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kcal")
                            .foregroundStyle(.secondary)
                    }
                    Stepper(value: $servings, in: 0.5...5.0, step: 0.5) {
                        HStack {
                            Text("人前")
                            Spacer()
                            Text(String(format: "%.1f", servings))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text("写真からのカロリーは目安です。正確な値は手動で修正してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("記録を確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("戻る") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(recipeName.isEmpty || calories.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let entry = FoodLogEntry(
            mealType: mealType,
            recipeName: recipeName,
            caloriesPerServing: Double(calories) ?? 0,
            servings: servings,
            source: .photo
        )
        context.insert(entry)
        onSave()
        dismiss()
    }
}

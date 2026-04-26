import SwiftUI
import PhotosUI
import Vision
import UIKit

// MARK: - Main Capture View

struct FoodPhotoCaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var analysisResult: FoodAnalysisResult?
    @State private var isAnalyzing = false
    @State private var showingCamera = false
    @State private var showingConfirm = false
    @State private var mealType: MealType = {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10: return .breakfast
        case 10..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    imagePreviewSection
                    sourceButtons
                    if capturedImage != nil {
                        mealTypePicker
                        analysisSection
                    }
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("写真から記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPickerView { image in
                    capturedImage = image
                    analyze(image)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImage = image
                        analyze(image)
                    }
                }
            }
            .sheet(isPresented: $showingConfirm) {
                if let result = analysisResult {
                    FoodLogAddFromPhotoView(
                        result: result,
                        mealType: mealType,
                        onSave: { dismiss() }
                    )
                }
            }
        }
    }

    // MARK: - Sections

    private var imagePreviewSection: some View {
        Group {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary)
                    .frame(height: 280)
                    .overlay {
                        VStack(spacing: 14) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 52))
                                .foregroundStyle(.secondary)
                            Text("食事の写真を撮影・選択してください")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
            }
        }
    }

    private var sourceButtons: some View {
        HStack(spacing: 12) {
            Button {
                showingCamera = true
            } label: {
                Label("カメラで撮影", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint.opacity(0.12))
                    .foregroundStyle(.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("ライブラリから", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private var mealTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("食事の種類")
                .font(.subheadline.bold())
            Picker("食事", selection: $mealType) {
                ForEach(MealType.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var analysisSection: some View {
        VStack(spacing: 16) {
            if isAnalyzing {
                analyzingView
            } else if let result = analysisResult {
                resultView(result)
            }
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("AIが料理を分析中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("少しお待ちください")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func resultView(_ result: FoodAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI分析結果", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(.purple)

            VStack(spacing: 8) {
                HStack {
                    Text("料理名")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(result.dishName)
                        .fontWeight(.medium)
                }
                Divider()
                HStack {
                    Text("推定カロリー")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(result.estimatedCalories) kcal")
                        .fontWeight(.semibold)
                        .foregroundStyle(.pink)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            Text("※ AIによる推定値です。修正してから保存できます")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showingConfirm = true
            } label: {
                Text("確認して記録する")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Analysis Pipeline

    private func analyze(_ image: UIImage) {
        isAnalyzing = true
        analysisResult = nil
        Task {
            // 1 & 2: Vision は背景スレッドで並列実行
            async let labels = extractVisionLabels(from: image)
            async let texts = extractText(from: image)
            let (l, t) = await (labels, texts)
            // 3: LLM は @MainActor（LLMService が @MainActor のため）
            let result = await analyzeWithLLM(labels: l, texts: t)
            await MainActor.run {
                self.analysisResult = result
                self.isAnalyzing = false
            }
        }
    }

    private func extractVisionLabels(from image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            // Vision は背景スレッドで実行してメインスレッドをブロックしない
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest { req, _ in
                    let labels = (req.results as? [VNClassificationObservation])?
                        .filter { $0.confidence > 0.15 }
                        .prefix(8)
                        .map { $0.identifier } ?? []
                    continuation.resume(returning: labels)
                }
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                if (try? handler.perform([request])) == nil {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func extractText(from image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { req, _ in
                    let texts = (req.results as? [VNRecognizedTextObservation])?
                        .compactMap { $0.topCandidates(1).first?.string }
                        .filter { !$0.isEmpty } ?? []
                    continuation.resume(returning: texts)
                }
                request.recognitionLanguages = ["ja-JP", "en-US"]
                request.recognitionLevel = .accurate
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                if (try? handler.perform([request])) == nil {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    @MainActor
    private func analyzeWithLLM(labels: [String], texts: [String]) async -> FoodAnalysisResult {
        let labelText = labels.isEmpty ? "不明" : labels.joined(separator: ", ")
        let textHint = texts.isEmpty ? "" : "\n画像内テキスト: \(texts.prefix(5).joined(separator: ", "))"

        let prompt = """
        食事画像の分析情報から、料理名と1人前のカロリーを推定してください。

        画像分類ラベル: \(labelText)\(textHint)

        回答形式（この形式だけで答えてください）:
        料理名|推定カロリー数値

        例: 炒飯|550
        例: 鶏の唐揚げ定食|720
        """

        guard let response = try? await LLMService.shared.generate(
            prompt: prompt,
            context: .foodAnalysis
        ) else {
            return FoodAnalysisResult(dishName: labels.first ?? "不明な料理", estimatedCalories: 500)
        }

        return parseAnalysisResponse(response)
    }

    private func parseAnalysisResponse(_ response: String) -> FoodAnalysisResult {
        // "料理名|カロリー" 形式をパース
        let line = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? response
        let parts = line.components(separatedBy: "|")
        if parts.count >= 2,
           let calories = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
            return FoodAnalysisResult(
                dishName: parts[0].trimmingCharacters(in: .whitespaces),
                estimatedCalories: calories
            )
        }
        // フォールバック：料理名だけ取れた場合
        let name = line.trimmingCharacters(in: .whitespaces)
        return FoodAnalysisResult(dishName: name.isEmpty ? "不明な料理" : name, estimatedCalories: 500)
    }
}

// MARK: - Analysis Result Model

struct FoodAnalysisResult {
    var dishName: String
    var estimatedCalories: Int
}

// MARK: - Camera Picker (UIImagePickerController)

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Confirm & Save

struct FoodLogAddFromPhotoView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let result: FoodAnalysisResult
    let mealType: MealType
    let onSave: () -> Void

    @State private var recipeName: String
    @State private var calories: String
    @State private var servings = 1.0

    init(result: FoodAnalysisResult, mealType: MealType, onSave: @escaping () -> Void) {
        self.result = result
        self.mealType = mealType
        self.onSave = onSave
        _recipeName = State(initialValue: result.dishName)
        _calories = State(initialValue: "\(result.estimatedCalories)")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("料理情報") {
                    TextField("料理名", text: $recipeName)

                    HStack {
                        Text("カロリー")
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
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        Text("AIによる推定値です。必要に応じて修正してください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                        .disabled(recipeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let entry = FoodLogEntry(
            mealType: mealType,
            recipeName: recipeName.trimmingCharacters(in: .whitespaces),
            caloriesPerServing: Double(calories) ?? 0,
            servings: servings,
            source: .photo
        )
        context.insert(entry)
        onSave()
        dismiss()
    }
}

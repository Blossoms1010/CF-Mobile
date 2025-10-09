import SwiftUI

struct ProfileSettingsView: View {
    @AppStorage("aiTransModels") private var modelsData: Data = Data()
    @State private var models: [AITranslationModel] = []
    @State private var showAddSheet = false
    @State private var editingModel: AITranslationModel?
    @State private var testingModelId: UUID?
    @State private var testResults: [UUID: TestResult] = [:]
    
    enum TestResult {
        case testing
        case success(String)
        case failure(String)
    }
    
    var body: some View {
        Form {
            // MARK: - Translation AI Models
            Section {
                // List of added models
                if models.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No AI models configured")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 30)
                        Spacer()
                    }
                } else {
                    ForEach(models) { model in
                        VStack(spacing: 0) {
                            Button {
                                editingModel = model
                            } label: {
                                AIModelCard(model: model, testResult: testResults[model.id])
                            }
                            .buttonStyle(.plain)
                            
                            // Test button area
                            HStack {
                                Button {
                                    testAPI(for: model)
                                } label: {
                                    HStack {
                                        if testingModelId == model.id {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "network")
                                        }
                                        Text("Test API")
                                            .font(.caption)
                                    }
                                }
                                .disabled(testingModelId == model.id)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                        }
                    }
                    .onDelete(perform: deleteModels)
                }
                
                // Add button
                Button {
                    showAddSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            } header: {
                Label("Translation AI Models", systemImage: "brain.head.profile")
                    .font(.headline)
            } footer: {
                Text("After configuring AI models, the \"Translate\" button becomes available on the problem page. Supports OpenAI-compatible interfaces.")
                    .font(.footnote)
            }
            
            // MARK: - Other Settings (Reserved)
            // More settings can be added here
        }
        .navigationTitle("Settings")
        .onAppear {
            loadModels()
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                AIModelEditView(model: nil) { newModel in
                    models.append(newModel)
                    saveModels()
                }
            }
        }
        .sheet(item: $editingModel) { model in
            NavigationStack {
                AIModelEditView(model: model) { updatedModel in
                    if let index = models.firstIndex(where: { $0.id == updatedModel.id }) {
                        models[index] = updatedModel
                        saveModels()
                    }
                }
            }
        }
    }
    
    private func loadModels() {
        if let decoded = try? JSONDecoder().decode([AITranslationModel].self, from: modelsData) {
            models = decoded
        }
    }
    
    private func saveModels() {
        if let encoded = try? JSONEncoder().encode(models) {
            modelsData = encoded
        }
    }
    
    private func deleteModels(at offsets: IndexSet) {
        models.remove(atOffsets: offsets)
        saveModels()
    }
    
    private func testAPI(for model: AITranslationModel) {
        testingModelId = model.id
        testResults[model.id] = .testing
        
        Task {
            do {
                let result = try await AIModelTester.testModel(
                    model: model.model,
                    apiEndpoint: model.apiEndpoint,
                    apiKey: model.apiKey
                )
                await MainActor.run {
                    testResults[model.id] = .success(result)
                    testingModelId = nil
                }
            } catch {
                await MainActor.run {
                    testResults[model.id] = .failure(error.localizedDescription)
                    testingModelId = nil
                }
            }
        }
    }
}

// MARK: - AI Model Card
struct AIModelCard: View {
    let model: AITranslationModel
    let testResult: ProfileSettingsView.TestResult?
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            // Information
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(model.model)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if !model.apiEndpoint.isEmpty {
                    Text(model.apiEndpoint)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                // Display test results
                if let result = testResult {
                    switch result {
                    case .testing:
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Testing...")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    case .success(let message):
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(message)
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    case .failure(let error):
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AI Model Edit View
struct AIModelEditView: View {
    @Environment(\.dismiss) private var dismiss
    let originalModel: AITranslationModel?
    let onSave: (AITranslationModel) -> Void
    
    @State private var name: String
    @State private var model: String
    @State private var apiEndpoint: String
    @State private var apiKey: String
    
    init(model: AITranslationModel?, onSave: @escaping (AITranslationModel) -> Void) {
        self.originalModel = model
        self.onSave = onSave
        _name = State(initialValue: model?.name ?? "")
        _model = State(initialValue: model?.model ?? "")
        _apiEndpoint = State(initialValue: model?.apiEndpoint ?? "")
        _apiKey = State(initialValue: model?.apiKey ?? "")
    }
    
    var isValid: Bool {
        !model.isEmpty && !apiEndpoint.isEmpty
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Model Name (for display)", text: $name)
                    .autocorrectionDisabled(true)
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
                
                TextField("Model (e.g. gpt-4o-mini or qwen2.5:14b)", text: $model)
                    .autocorrectionDisabled(true)
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
                
                TextField("Proxy API (OpenAI-compatible chat/completions endpoint)", text: $apiEndpoint)
                    .keyboardType(.URL)
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled(true)
                
                SecureField("API Key (optional; required by some proxies or direct OpenAI)", text: $apiKey)
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled(true)
            } footer: {
                Text("Fill in model name, model ID, and proxy API. Example: https://your-proxy/v1/chat/completions")
                    .font(.footnote)
            }
        }
        .navigationTitle(originalModel == nil ? "Add Model" : "Edit Model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let newModel = AITranslationModel(
                        id: originalModel?.id ?? UUID(),
                        name: name,
                        model: model,
                        apiEndpoint: apiEndpoint,
                        apiKey: apiKey
                    )
                    onSave(newModel)
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
    }
}


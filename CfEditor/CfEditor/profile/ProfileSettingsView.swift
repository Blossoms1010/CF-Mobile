import SwiftUI

struct ProfileSettingsView: View {
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("aiTransModels") private var modelsData: Data = Data()
    @State private var models: [AITranslationModel] = []
    @State private var showAddSheet = false
    @State private var editingModel: AITranslationModel?
    @State private var testingModelId: UUID?
    @State private var testResults: [UUID: TestResult] = [:]
    @StateObject private var templateManager = CodeTemplateManager.shared
    @State private var editingLanguage: ProgrammingLanguage?
    
    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? .system
    }
    
    enum TestResult {
        case testing
        case success(String)
        case failure(String)
    }
    
    var body: some View {
        Form {
            // MARK: - Theme Settings
            Section {
                ForEach(AppTheme.allCases) { theme in
                    HStack {
                        Image(systemName: theme.icon)
                            .foregroundStyle(appTheme == theme ? .blue : .secondary)
                            .frame(width: 30)
                        
                        Text(theme.displayName)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if appTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .font(.body.weight(.semibold))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appThemeRaw = theme.rawValue
                    }
                }
            } header: {
                Label("主题", systemImage: "paintbrush.fill")
                    .font(.headline)
            } footer: {
                Text("选择您偏好的应用主题")
                    .font(.footnote)
            }
            
            // MARK: - Code Templates
            Section {
                ForEach(ProgrammingLanguage.allCases) { language in
                    Button {
                        editingLanguage = language
                    } label: {
                        HStack {
                            Image(systemName: language.icon)
                                .foregroundStyle(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language.rawValue)
                                    .foregroundStyle(.primary)
                                    .font(.body)
                                
                                Text("\(templateManager.getTemplate(for: language).count) characters")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Label("Code Templates", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.headline)
            } footer: {
                Text("Customize default code templates for each language")
                    .font(.footnote)
            }
            
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
            
            // 底部占位空间，防止被遮挡
            Section {
                Color.clear
                    .frame(height: 60)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
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
        .sheet(item: $editingLanguage) { language in
            NavigationStack {
                CodeTemplateEditView(language: language)
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

// MARK: - Code Template Edit View
struct CodeTemplateEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var templateManager = CodeTemplateManager.shared
    let language: ProgrammingLanguage
    
    @State private var code: String = ""
    @State private var showResetAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header info
            HStack(spacing: 12) {
                Image(systemName: language.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.rawValue)
                        .font(.headline)
                    Text("Edit your code template")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
            
            Divider()
            
            // Code editor
            TextEditor(text: $code)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                #if !os(macOS)
                .textInputAutocapitalization(.never)
                #endif
                .padding(8)
        }
        .navigationTitle("\(language.rawValue) Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    templateManager.updateTemplate(for: language, code: code)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
            
            ToolbarItem(placement: .bottomBar) {
                Button {
                    showResetAlert = true
                } label: {
                    Label("Reset to Default", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .onAppear {
            code = templateManager.getTemplate(for: language)
        }
        .alert("Reset Template", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                code = language.defaultTemplate
                templateManager.resetTemplate(for: language)
            }
        } message: {
            Text("This will reset the template to its default value. This action cannot be undone.")
        }
    }
}


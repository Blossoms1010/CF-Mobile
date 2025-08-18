import SwiftUI
import WebKit

struct SubmitSheetView: View {
	let contestId: Int
	let problemIndex: String
	@Binding var selectedLanguageKey: String
	let onSubmit: (_ programTypeId: String, _ displayText: String) -> Void

	@AppStorage("cfHandle") private var storedHandle: String = ""

	@State private var cookieHandle: String? = nil
	@State private var isLoginSheetPresented: Bool = false

	@State private var languageOptions: [(id: String, text: String)] = []
	@State private var selectedProgramTypeId: String? = nil
	@State private var isLoading: Bool = false
	@State private var loadError: String? = nil
	@State private var showWebHelper: Bool = false
	@StateObject private var webHelperModel = WebViewModel(enableProblemReader: false)

	private var hasCFLogin: Bool {
		let t1 = (cookieHandle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		let t2 = storedHandle.trimmingCharacters(in: .whitespacesAndNewlines)
		return !t1.isEmpty || !t2.isEmpty
	}

	var body: some View {
		NavigationStack {
			ZStack {
				content
				if !hasCFLogin { loginOverlay }
			}
			.navigationTitle("提交到 Codeforces")
			.navigationBarTitleDisplayMode(.inline)
		}
		.onAppear {
			Task {
				CFCookieBridge.shared.startObserving()
				await CFCookieBridge.shared.syncFromWKToHTTPCookieStorage()
				await trySyncOtherStoreIfNeeded()
				refreshCFHandle()
				await loadLanguageOptions()
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .NSHTTPCookieManagerCookiesChanged)) { _ in
			Task { refreshCFHandle() }
		}
		.onChange(of: isLoginSheetPresented) { oldValue, newValue in
			// 登录页收起后，强制同步并刷新一次，避免延迟导致的“仍锁定”现象
			if oldValue == true && newValue == false {
				Task {
					await CFCookieBridge.shared.syncFromWKToHTTPCookieStorage()
					await trySyncOtherStoreIfNeeded()
					for delay in [0.0, 0.25, 0.6, 1.2] {
						if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
						refreshCFHandle()
						if hasCFLogin { break }
					}
				}
			}
		}
		.sheet(isPresented: $isLoginSheetPresented) {
			NavigationStack { BindCFAccountView() }
		}
		.sheet(isPresented: $showWebHelper) {
			NavigationStack {
				VStack(spacing: 0) {
					WebView(model: webHelperModel)
				}
				.navigationTitle("提交页（网页）")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .navigationBarLeading) {
						Button("关闭") { showWebHelper = false }
					}
					ToolbarItem(placement: .navigationBarTrailing) {
						Button("打开首页") { webHelperModel.load(urlString: "https://codeforces.com") }
					}
				}
			}
			.onAppear {
				let submit = "https://codeforces.com/contest/\(contestId)/submit?submittedProblemIndex=\(problemIndex)"
				let referer = "https://codeforces.com/contest/\(contestId)/problem/\(problemIndex)"
				webHelperModel.load(urlString: submit, referer: referer)
			}
			.onDisappear {
				Task {
					await CFCookieBridge.shared.syncFromWKToHTTPCookieStorage()
					await trySyncOtherStoreIfNeeded()
					await loadLanguageOptions()
				}
			}
		}
	}

	@ViewBuilder
	private var content: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("选择语言")
				.font(.headline)
				.padding(.horizontal, 12)

			if let err = loadError {
				VStack(spacing: 8) {
					Text("加载语言选项失败")
						.font(.subheadline)
						.foregroundStyle(.secondary)
					Text(err).font(.footnote).foregroundStyle(.secondary)
					HStack(spacing: 12) {
						Button("重试") { Task { await loadLanguageOptions() } }
						Button("在网页中打开提交页") { showWebHelper = true }
					}
				}
				.padding(.horizontal, 12)
			} else if isLoading {
				VStack(spacing: 8) {
					ProgressView()
					Text("正在加载语言选项…").font(.footnote).foregroundStyle(.secondary)
				}
				.padding(.horizontal, 12)
			} else {
				List {
					ForEach(languageOptions, id: \.id) { opt in
						HStack {
							Text(opt.text)
							Spacer()
							if selectedProgramTypeId == opt.id {
								Image(systemName: "checkmark").foregroundStyle(.tint)
							}
						}
						.contentShape(Rectangle())
						.onTapGesture {
							withAnimation(.easeInOut(duration: 0.15)) {
								selectedProgramTypeId = opt.id
								if let mapped = mapDisplayTextToLanguageKey(opt.text) { selectedLanguageKey = mapped }
							}
						}
					}
				}
				.listStyle(.insetGrouped)
			}

			HStack {
				Spacer()
				Button(action: {
					if let id = selectedProgramTypeId, let text = languageOptions.first(where: { $0.id == id })?.text {
						onSubmit(id, text)
					}
				}) {
					Label("确认提交", systemImage: "paperplane.fill")
				}
				.buttonStyle(.borderedProminent)
				.disabled(!hasCFLogin || selectedProgramTypeId == nil)
			}
			.padding(.horizontal, 12)
			.padding(.bottom, 8)
		}
	}

	@ViewBuilder
	private var loginOverlay: some View {
		VStack(spacing: 12) {
			Image(systemName: "lock.fill").font(.system(size: 28)).foregroundStyle(.secondary)
			Text("未登录 Codeforces")
				.font(.headline)
			Text("请先登录，登录成功后可在此直接提交。")
				.font(.footnote)
				.foregroundStyle(.secondary)
			HStack(spacing: 12) {
				Button(action: { isLoginSheetPresented = true }) {
					Text("去登录")
						.font(.subheadline)
				}
				.buttonStyle(.borderedProminent)
				Button(action: { showWebHelper = true }) {
					Text("打开网页")
						.font(.subheadline)
				}
			}
		}
		.padding(20)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color(.systemBackground).opacity(0.98))
	}

	private func refreshCFHandle() {
		Task {
			let h = await CFCookieBridge.shared.readCurrentCFHandleFromWK()
			await MainActor.run { self.cookieHandle = h }
		}
	}

	private func loadLanguageOptions() async {
		await MainActor.run { isLoading = true; loadError = nil }
		do {
			let opts = try await CFSubmitClient.fetchLanguageOptions(contestId: contestId, index: problemIndex)
			await MainActor.run {
				self.languageOptions = opts
				self.selectedProgramTypeId = pickRecommendedProgramTypeId(from: opts, for: selectedLanguageKey)
				self.isLoading = false
			}
		} catch {
			await MainActor.run {
				self.loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
				self.isLoading = false
			}
		}
	}

	private func pickRecommendedProgramTypeId(from options: [(id: String, text: String)], for languageKey: String) -> String? {
		func score(for text: String) -> Int {
			let t = text.lowercased()
			switch languageKey {
			case "cpp":
				var s = 0
				if t.contains("c++") || t.contains("g++") { s += 6 }
				if t.contains("gnu") { s += 3 }
				if t.contains("23") { s += 5 }
				else if t.contains("20") { s += 4 }
				else if t.contains("17") { s += 3 }
				else if t.contains("11") { s += 1 }
				if t.contains("64") { s += 1 }
				if t.contains("clang") { s -= 4 }
				if t.contains("mingw") { s -= 2 }
				return s
			case "python":
				var s = 0
				if t.contains("python") || t.contains("pypy") { s += 6 }
				if t.contains("3") { s += 4 }
				if t.contains("pypy") { s += 2 }
				if t.contains("64") { s += 1 }
				if t.contains("2") { s -= 8 }
				return s
			case "java":
				var s = 0
				if t.contains("java") { s += 6 }
				if t.contains("21") { s += 4 }
				else if t.contains("17") { s += 3 }
				else if t.contains("11") { s += 2 }
				if t.contains("openjdk") || t.contains("jdk") { s += 1 }
				return s
			default:
				return 0
			}
		}
		return options.max(by: { score(for: $0.text) < score(for: $1.text) })?.id
	}

	private func mapDisplayTextToLanguageKey(_ text: String) -> String? {
		let t = text.lowercased()
		if t.contains("c++") || t.contains("g++") { return "cpp" }
		if (t.contains("python") || t.contains("pypy")) && t.contains("3") { return "python" }
		if t.contains("java") { return "java" }
		return nil
	}

	private func trySyncOtherStoreIfNeeded() async {
		let currentEphemeral = UserDefaults.standard.bool(forKey: "web.useEphemeral")
		let currentStore: WKHTTPCookieStore = WebDataStoreProvider.shared.currentStore().httpCookieStore
		let otherStore: WKHTTPCookieStore = currentEphemeral ? WebDataStoreProvider.shared.persistentStore().httpCookieStore : WebDataStoreProvider.shared.sharedEphemeralStore().httpCookieStore

		func readXUser(from store: WKHTTPCookieStore) async -> String? {
			return await withCheckedContinuation { (cc: CheckedContinuation<String?, Never>) in
				store.getAllCookies { cookies in
					let candidates = cookies.filter { $0.name == "X-User" && $0.domain.lowercased().hasSuffix("codeforces.com") }
					let chosen = candidates.max { ($0.expiresDate ?? .distantFuture) < ($1.expiresDate ?? .distantFuture) }
					cc.resume(returning: chosen?.value)
				}
			}
		}

		func readAllCFCookies(from store: WKHTTPCookieStore) async -> [HTTPCookie] {
			return await withCheckedContinuation { (cc: CheckedContinuation<[HTTPCookie], Never>) in
				store.getAllCookies { cookies in
					let filtered = cookies.filter { $0.domain.lowercased().contains("codeforces.com") }
					cc.resume(returning: filtered)
				}
			}
		}

		let currentX = await readXUser(from: currentStore)
		if currentX != nil { return }
		let otherX = await readXUser(from: otherStore)
		guard otherX != nil else { return }
		let cfCookies = await readAllCFCookies(from: otherStore)
		let storage = HTTPCookieStorage.shared
		for c in cfCookies { storage.setCookie(c) }
		await CFCookieBridge.shared.syncFromHTTPCookieStorageToWK()
	}
}



//
//  CleanupView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 15/8/25.
//

import SwiftUI

enum SelectionState {
    case none
    case partial
    case full
    
    var checkboxState: CheckboxState {
        switch self {
        case .none: return .unchecked
        case .partial: return .mixed
        case .full: return .checked
        }
    }
}

// MARK: - View Model
@MainActor
class CleanupViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedCategories: Set<String> = []
    @Published var selectedCategoryForPreview: CleanupCategory? = nil
    @Published var selectedFilesByCategory: [String: Set<String>] = [:]
    @Published var isLoadingFiles = false
    @Published var currentCategoryFiles: [CleanupFile] = []
    
    // MARK: - Private Properties
    private let cleanerService: CleanerService
    private var filesCache: [String: [CleanupFile]] = [:]
    private var displayedFilesCache: [String: [CleanupFile]] = [:]
    private var loadedItemsCount: [String: Int] = [:]
    
    // MARK: - Constants
    private struct Constants {
        static let itemsPerBatch = 100
        static let initialBatchSize = 20
        static let loadMoreThreshold = 10
        static let maxCategoriesInMemory = 3
        static let maxItemsPerCategory = 5000
    }

    init(cleanerService: CleanerService) {
        self.cleanerService = cleanerService
    }

    // MARK: - Computed Properties
    var categories: [CleanupCategory] {
        cleanerService.scanResult?.categories ?? []
    }
    
    var selectedCategorySize: UInt64 {
        guard let selectedCategory = selectedCategoryForPreview else { return 0 }
        return selectedCategory.size
    }
    
    var selectedTotalSize: UInt64 {
        var totalSize: UInt64 = 0
        
        for categoryId in selectedCategories {
            if let category = categories.first(where: { $0.id == categoryId }) {
                totalSize += category.size
            }
        }
        
        for (categoryId, filePaths) in selectedFilesByCategory {
            guard !filePaths.isEmpty else { continue }
            
            if selectedCategories.contains(categoryId) {
                continue
            }
            
            if let cachedFiles = filesCache[categoryId] {
                let selectedFiles = cachedFiles.filter { filePaths.contains($0.path) }
                totalSize += selectedFiles.reduce(0) { $0 + $1.size }
            } else if let category = categories.first(where: { $0.id == categoryId }) {
                let allFiles = getAllCachedFiles(for: categoryId)
                if !allFiles.isEmpty {
                    if filePaths.count == allFiles.count {
                        totalSize += category.size
                    } else {
                        let ratio = Double(filePaths.count) / Double(allFiles.count)
                        totalSize += UInt64(Double(category.size) * ratio)
                    }
                }
            }
        }
        
        return totalSize
    }
    
    var selectedFiles: Set<String> {
        guard let categoryId = selectedCategoryForPreview?.id else { return [] }
        return selectedFilesByCategory[categoryId] ?? []
    }
    
    var hasMoreItems: Bool {
        guard let categoryId = selectedCategoryForPreview?.id,
              let totalFiles = filesCache[categoryId]?.count,
              let currentLoaded = loadedItemsCount[categoryId] else {
            return false
        }
        return currentLoaded < totalFiles
    }
    
    var hasAnySelections: Bool {
        return !selectedCategories.isEmpty ||
               selectedFilesByCategory.values.contains { !$0.isEmpty }
    }
    
    var categoriesSelectAllState: SelectionState {
        let states = categories.map { getCategorySelectionState($0) }
        
        if states.allSatisfy({ $0 == .full }) {
            return .full
        } else if states.allSatisfy({ $0 == .none }) {
            return .none
        } else {
            return .partial
        }
    }
    
    var filesSelectAllState: SelectionState {
        let totalFiles = currentCategoryFiles.count
        let selectedFilesCount = currentCategoryFiles.filter { isFileSelected($0.path) }.count
        
        switch selectedFilesCount {
        case 0: return .none
        case totalFiles: return .full
        default: return .partial
        }
    }

    func selectCategoryForPreview(_ category: CleanupCategory) async {
        selectedCategoryForPreview = category
        isLoadingFiles = true
        
        await loadCategoryFiles(category)
        updateCurrentCategoryFiles()
        
        isLoadingFiles = false
    }
    
    @MainActor
    private func loadCategoryFiles(_ category: CleanupCategory) async {
        if let cachedFiles = filesCache[category.id] {
            cleanerService.currentFiles = cachedFiles
        } else {
            await cleanerService.loadFilesForCategory(category)
            filesCache[category.id] = cleanerService.currentFiles
        }

        if selectedCategories.contains(category.id) {
            selectedFilesByCategory[category.id] = Set(cleanerService.currentFiles.map { $0.path })
        }
        
        loadInitialBatch(for: category.id)
    }

    func getCategorySelectionState(_ category: CleanupCategory) -> SelectionState {
        let isFullySelected = selectedCategories.contains(category.id)
        let individualFiles = selectedFilesByCategory[category.id]
        
        if isFullySelected && individualFiles == nil {
            return .full
        }
        
        if let selectedFiles = individualFiles, !selectedFiles.isEmpty {
            if selectedCategoryForPreview?.id == category.id {
                let totalFiles = currentCategoryFiles.count
                return selectedFiles.count == totalFiles ? .full : .partial
            } else {
                return .partial
            }
        }
        
        return isFullySelected ? .full : .none
    }

    func toggleCategorySelection(_ categoryId: String, to newState: SelectionState) {
        switch newState {
        case .full:
            selectedCategories.insert(categoryId)
            selectedFilesByCategory.removeValue(forKey: categoryId)
            
        case .none:
            selectedCategories.remove(categoryId)
            selectedFilesByCategory.removeValue(forKey: categoryId)
            
        case .partial:
            selectedCategories.insert(categoryId)
            selectedFilesByCategory.removeValue(forKey: categoryId)
        }
    }

    func toggleAllCategories() {
        let newState: SelectionState = categoriesSelectAllState == .full ? .none : .full
        
        switch newState {
        case .full:
            selectedCategories = Set(categories.map { $0.id })
            selectedFilesByCategory.removeAll()
        case .none:
            selectedCategories.removeAll()
            selectedFilesByCategory.removeAll()
        case .partial:
            break
        }
    }

    // MARK: - File Selection Methods
    func isFileSelected(_ filePath: String) -> Bool {
        guard let categoryId = selectedCategoryForPreview?.id else { return false }
        return selectedFilesByCategory[categoryId]?.contains(filePath) ?? false
    }

    func toggleFileSelection(_ filePath: String, to newState: SelectionState) {
        guard let categoryId = selectedCategoryForPreview?.id else { return }
        
        if selectedCategories.contains(categoryId) {
            moveToIndividualFileSelection(for: categoryId)
        }
        
        var categoryFiles = selectedFilesByCategory[categoryId] ?? []
        
        switch newState {
        case .full:
            categoryFiles.insert(filePath)
        case .none:
            categoryFiles.remove(filePath)
        case .partial:
            // Toggle
            if categoryFiles.contains(filePath) {
                categoryFiles.remove(filePath)
            } else {
                categoryFiles.insert(filePath)
            }
        }
        
        if categoryFiles.isEmpty {
            selectedFilesByCategory.removeValue(forKey: categoryId)
        } else {
            selectedFilesByCategory[categoryId] = categoryFiles
        }
    }

    func toggleAllFiles() {
        guard let categoryId = selectedCategoryForPreview?.id else { return }
        
        let newState: SelectionState = filesSelectAllState == .full ? .none : .full
        
        selectedCategories.remove(categoryId)
        
        switch newState {
        case .full:
            let allFilePaths = Set(getAllCachedFiles(for: categoryId).map { $0.path })
            selectedFilesByCategory[categoryId] = allFilePaths
        case .none:
            selectedFilesByCategory.removeValue(forKey: categoryId)
        case .partial:
            break
        }
    }
    
    private func moveToIndividualFileSelection(for categoryId: String) {
        if selectedCategories.contains(categoryId) {
            selectedCategories.remove(categoryId)
            let allFilePaths = Set(getAllCachedFiles(for: categoryId).map { $0.path })
            selectedFilesByCategory[categoryId] = allFilePaths
        }
    }
    
    private func getAllCachedFiles(for categoryId: String) -> [CleanupFile] {
        if selectedCategoryForPreview?.id == categoryId {
            return filesCache[categoryId] ?? cleanerService.currentFiles
        } else {
            return filesCache[categoryId] ?? []
        }
    }

    // MARK: - Pagination Methods
    private func loadInitialBatch(for categoryId: String) {
        guard let allFiles = filesCache[categoryId] else {
            return
        }
        
        let batchSize = min(Constants.initialBatchSize, allFiles.count)
        displayedFilesCache[categoryId] = Array(allFiles.prefix(batchSize))
        loadedItemsCount[categoryId] = batchSize
        
    }
    
    func loadMoreIfNeeded(currentIndex: Int) {
        guard let categoryId = selectedCategoryForPreview?.id,
              let allFiles = filesCache[categoryId],
              let currentLoaded = loadedItemsCount[categoryId] else {
            return
        }
        
        let shouldLoadMore = currentIndex >= currentLoaded - Constants.loadMoreThreshold &&
                           currentLoaded < allFiles.count
        
        guard shouldLoadMore else { return }
        
        let newBatchSize = min(Constants.itemsPerBatch, allFiles.count - currentLoaded)
        let newItems = Array(allFiles[currentLoaded..<(currentLoaded + newBatchSize)])
        
        displayedFilesCache[categoryId]?.append(contentsOf: newItems)
        loadedItemsCount[categoryId] = currentLoaded + newBatchSize
        
        updateCurrentCategoryFiles()
        
    }
    
    private func updateCurrentCategoryFiles() {
        guard let categoryId = selectedCategoryForPreview?.id else {
            currentCategoryFiles = []
            return
        }
        
        currentCategoryFiles = displayedFilesCache[categoryId] ?? []
    }

    // MARK: - Cleanup Methods
    func closeFilePreview() {
        selectedCategoryForPreview = nil
        currentCategoryFiles = []
        limitMemoryUsage()
    }
    
    private func limitMemoryUsage() {
        if displayedFilesCache.count > Constants.maxCategoriesInMemory {
            let keysToRemove = Array(displayedFilesCache.keys.prefix(
                displayedFilesCache.count - Constants.maxCategoriesInMemory
            ))
            keysToRemove.forEach { key in
                displayedFilesCache.removeValue(forKey: key)
                loadedItemsCount.removeValue(forKey: key)
            }
        }
        
        for (categoryId, items) in displayedFilesCache {
            if items.count > Constants.maxItemsPerCategory {
                displayedFilesCache[categoryId] = Array(items.prefix(Constants.maxItemsPerCategory))
                loadedItemsCount[categoryId] = Constants.maxItemsPerCategory
            }
        }
    }

    // MARK: - Cleanup Execution
    @MainActor
    func performCleanup() async throws {
        let cleanupData = prepareCleanupData()

        switch cleanupData.type {
        case .categoriesOnly(let categories):
            let categoriesToClean = categories.map { category in
                var mutableCategory = category
                mutableCategory.isSelected = true
                return mutableCategory
            }
            
            _ = try await cleanerService.cleanupCategories(categoriesToClean) { progress in
                await MainActor.run {
                }
            }

        case .filesOnly(_):
            _ = try await cleanerService.cleanupSpecificFiles(cleanupData) { progress in
                await MainActor.run {
                }
            }

        case .hybrid(_, _):
            _ = try await cleanerService.cleanupSpecificFiles(cleanupData) { progress in
                await MainActor.run {
                }
            }
        }
        
        resetAfterCleanup()
    }
    
    private func prepareCleanupData() -> CleanupData {
        var fullCategoriesIds = selectedCategories
        var specificFilesByCategory: [String: [CleanupFile]] = [:]

        for (categoryId, filePaths) in selectedFilesByCategory {
            guard !filePaths.isEmpty else { continue }

            let selectedCategoryFiles = getSelectedFilesForCategory(categoryId, filePaths: filePaths)
            
            let allFiles = getAllCachedFiles(for: categoryId)
            let allFilesSelected = filePaths.count == allFiles.count
            
            if allFilesSelected {
                fullCategoriesIds.insert(categoryId)
            } else {
                fullCategoriesIds.remove(categoryId)
                specificFilesByCategory[categoryId] = selectedCategoryFiles
            }
        }

        let fullCategories = categories.filter { fullCategoriesIds.contains($0.id) }

        if !fullCategories.isEmpty && !specificFilesByCategory.isEmpty {
            return CleanupData(type: .hybrid(fullCategories, specificFilesByCategory))
        } else if !fullCategories.isEmpty {
            return CleanupData(type: .categoriesOnly(fullCategories))
        } else {
            return CleanupData(type: .filesOnly(specificFilesByCategory))
        }
    }
    
    private func getSelectedFilesForCategory(_ categoryId: String, filePaths: Set<String>) -> [CleanupFile] {
        if let cachedFiles = filesCache[categoryId] {
            return cachedFiles.filter { filePaths.contains($0.path) }
        } else {
            return filePaths.map { path in
                CleanupFile(
                    id: UUID().uuidString,
                    categoryId: categoryId,
                    name: URL(fileURLWithPath: path).lastPathComponent,
                    path: path,
                    size: 0,
                    isDirectory: false,
                    canDelete: true
                )
            }
        }
    }
    
    @MainActor
    func resetAfterCleanup() {
     
        selectedCategories.removeAll()
        selectedFilesByCategory.removeAll()
        selectedCategoryForPreview = nil
        currentCategoryFiles = []
        
        filesCache.removeAll()
        displayedFilesCache.removeAll()
        loadedItemsCount.removeAll()
        
      
        isLoadingFiles = false
        
     
    }
}

struct CleanupView: View {
    @ObservedObject private var viewModel: CleanupViewModel
    @StateObject var cleanerService: CleanerService
    @State private var isInitialized = false
    @State private var showingHelperAlert = false
    @State private var helperStatus: CleanerService.HelperStatusType?
    @State private var showModalConfirmCleanup = false
    

    init(cleanerService: CleanerService) {
         self._cleanerService = StateObject(wrappedValue: cleanerService)
         self.viewModel = cleanerService.cleanupViewModel
       
     }
    
    var body: some View {
        ZStack{
            VStack(spacing: 0) {
                contentArea
                Spacer()
                bottomSection
            }
            
            if showModalConfirmCleanup {
                CustomModalView(
                    title: "CLEANER_CONFIRM_CLEANUP_TITLE",
                    message: "CLEANER_CONFIRM_CLEANUP_MESSAGE",
                    cancelTitle: "COMMON_CANCEL",
                    confirmTitle: "CLEANER_DELETE_FILES",
                    confirmColor: .blue,
                    onCancel: {
                        self.showModalConfirmCleanup = false
                    },
                    onConfirm: {
                        Task {
                            try await viewModel.performCleanup()
                        }
                     
                    }
                )
            }
        }
        .frame(width: 630, height: 400)
        .onAppear {
            initializeIfNeeded()
        }
        .alert("CLEANER_CLEANING_SERVICE", isPresented: $showingHelperAlert) {
            if let status = helperStatus {
                if status.shouldShowSystemSettings {
                    Button("CLEANER_OPEN_SYSTEM_SETTINGS") {
                        cleanerService.openSystemSettings()
                    }
                    Button("CLEANER_CANCEL") { }
                } else {
                    Button("CLEANER_RETRY") {
                        Task { await cleanerService.scanCategories() }
                    }
                    Button("CLEANER_REINSTALL_HELPER") {
                        Task { await cleanerService.reinstallHelper() }
                    }
                    Button("CLEANER_CANCEL") { }
                }
            } else {
                Button("CLEANER_OK") { }
            }
        } message: {
            if let status = helperStatus {
                Text(status.userMessage)
            }
        }
        .alert("CLEANER_ERROR_TITLE", isPresented: .constant(cleanerService.errorMessage != nil && !showingHelperAlert)) {
            Button("CLEANER_RETRY") {
                Task {
                    await retryWithStatusCheck()
                }
            }
            Button("CLEANER_OK") { }
        } message: {
            if let errorMessage = cleanerService.errorMessage {
                Text(errorMessage)
            }
        }

    }
        
    private func initializeIfNeeded() {
        guard !isInitialized && !cleanerService.isScanning else { return }
        
        print("🚀 Iniciando escaneo")
        Task {
            await scanWithStatusCheck()
            isInitialized = true
        }
    }
 
    private func scanWithStatusCheck() async {
        let status = await cleanerService.getHelperStatus()
        print("Helper status: \(status)")
        
        if status.isError {
            await MainActor.run {
                helperStatus = status
                showingHelperAlert = true
            }
        }
        
        await cleanerService.scanCategories()
    }
    
    private func retryWithStatusCheck() async {
        cleanerService.state = .idle
        
        let status = await cleanerService.getHelperStatus()
        
        if status.canAutoRegister {
            let registered = await cleanerService.tryRegisterHelper()
            
            if registered {
                await cleanerService.scanCategories()
                return
            }
        }
        
        if status.isError {
            await MainActor.run {
                helperStatus = status
                showingHelperAlert = true
            }
            return
        }
        
        await cleanerService.scanCategories()
    }
}


// MARK: - View Extensions
extension CleanupView {
    private var contentArea: some View {
        ZStack {
            mainContentView
            
            if viewModel.selectedCategoryForPreview != nil {
                HStack {
                    Spacer()
                    fileListView
                }
                .transition(.move(edge: .trailing))
                .animation(.easeInOut(duration: 0.3), value: viewModel.selectedCategoryForPreview)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.DefaultBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var bottomSection: some View {
        Group {
            if cleanerService.isScanning {
                progressView(text: "CLEANER_SCANNING")
            } else if cleanerService.isCleaning {
                progressView(text: "CLEANER_CLEANING")
            } else {
                AppButton(title: "CLEANER_CLEAN_UP") {
                    Task {
                        self.showModalConfirmCleanup = true
                      
                    }
                }
                .disabled(!viewModel.hasAnySelections)
                .padding(.bottom, 20)
            }
        }
    }

    private func progressView(text: String) -> some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            AppText(text)
                .font(.BaseRegular)
                .foregroundColor(.DefaultText)
        }
        .padding(.bottom, 20)
    }

    private var mainContentView: some View {
        HStack(spacing: 0) {
            categoriesSection
            Divider()
            storageMeterSection
        }
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            categoriesHeader
            Divider().padding(.horizontal, 16)
            categoriesContent
        }
        .frame(width: 320)
    }
    
    private var categoriesHeader: some View {
        HStack {
            AppText(ConfigLoader().getDeviceName() ?? "Mac osx")
                .font(.LGMedium)
                .foregroundColor(.Gray100)
            
            Spacer()
            
            selectAllButton(
                state: viewModel.categoriesSelectAllState,
                action: viewModel.toggleAllCategories
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    private var categoriesContent: some View {
        Group {
            if cleanerService.isScanning {
                loadingView(text: "CLEANER_SCANNING_CATEGORIES")
            } else {
                categoriesList
            }
        }
        .frame(height: 280)
    }
    
    private var categoriesList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.categories.enumerated()), id: \.element.id) { index, category in
                    CategoryRow(
                        category: category,
                        checkboxState: viewModel.getCategorySelectionState(category).checkboxState,
                        isHighlighted: viewModel.selectedCategoryForPreview?.id == category.id,
                        onToggle: { newState in
                            let selectionState = SelectionState.from(checkboxState: newState)
                            viewModel.toggleCategorySelection(category.id, to: selectionState)
                        },
                        onTap: {
                            Task {
                                await viewModel.selectCategoryForPreview(category)
                            }
                        }
                    )
                    .background(Color.clear)
                    
                    if index < viewModel.categories.count - 1 {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    private var storageMeterSection: some View {
        VStack(spacing: 0) {
            StorageMeterView(
                scanResult: cleanerService.scanResult,
                selectedCategoryForPreview: viewModel.selectedCategoryForPreview,
                selectedCategorySize: viewModel.selectedCategorySize,
                selectedCategories: viewModel.selectedCategories,
                selectedTotalSize: viewModel.selectedTotalSize,
                selectedFilesByCategory: viewModel.selectedFilesByCategory
            )
        }
        .frame(width: 270)
    }

    
    private var fileListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            fileListHeader
            Divider().padding(.horizontal, 16)
            fileListContent
        }
        .frame(width: 350)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 10,
                topTrailingRadius: 10
            )
            .fill(Color(NSColor.controlBackgroundColor))
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 10,
                    topTrailingRadius: 10
                )
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: -5, y: 0)
    }
    
    private var fileListHeader: some View {
        HStack {
            Button(action: viewModel.closeFilePreview) {
                Image(systemName: "chevron.right.2")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            selectAllButton(
                state: viewModel.filesSelectAllState,
                action: viewModel.toggleAllFiles
            )
            .disabled(viewModel.isLoadingFiles)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    private var fileListContent: some View {
        Group {
            if viewModel.isLoadingFiles {
                loadingView(text: "CLEANER_LOADING_FILES")
            } else {
                filesList
            }
        }
        .frame(height: 280)
    }
    
    private var filesList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.currentCategoryFiles.enumerated()), id: \.element.id) { index, file in
                    FileRow(
                        file: file,
                        checkboxState: viewModel.isFileSelected(file.path) ? .checked : .unchecked
                    ) { newState in
                        let selectionState = SelectionState.from(checkboxState: newState)
                        viewModel.toggleFileSelection(file.path, to: selectionState)
                    }
                    .background(Color.clear)
                    .onAppear {
                        if index >= viewModel.currentCategoryFiles.count - 10 {
                            viewModel.loadMoreIfNeeded(currentIndex: index)
                        }
                    }
                    
                    if index < viewModel.currentCategoryFiles.count - 1 {
                        Divider().padding(.horizontal, 16)
                    }
                }
                
                if viewModel.hasMoreItems {
                    loadMoreIndicator
                }
            }
            .padding(.bottom, 8)
        }
    }
    
    private var loadMoreIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            AppText("CLEANER_LOADING_MORE")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .onAppear {
            viewModel.loadMoreIfNeeded(currentIndex: viewModel.currentCategoryFiles.count - 1)
        }
    }
    
    private func loadingView(text: String) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ProgressView()
                AppText(text)
                    .font(.BaseRegular)
                    .foregroundColor(.DefaultText)
                Spacer()
            }
            Spacer()
        }
    }
    
    private func selectAllButton(state: SelectionState, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: action) {
                CheckboxView(state: state.checkboxState)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 24, minHeight: 24)
            .contentShape(Rectangle())
            
            Button("CLEANER_SELECT_ALL", action: action)
                .buttonStyle(PlainButtonStyle())
                .font(.BaseRegular)
                .foregroundColor(.DefaultText)
        }
    }
}

// MARK: - Helper Extensions
extension SelectionState {
    static func from(checkboxState: CheckboxState) -> SelectionState {
        switch checkboxState {
        case .unchecked: return .none
        case .mixed: return .partial
        case .checked: return .full
        }
    }
}

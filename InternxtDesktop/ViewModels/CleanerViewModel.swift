//
//  CleanerViewModel.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 31/3/26.
//

import Foundation

@MainActor
class CleanupViewModel: ObservableObject {
   
   
    @Published var selectedCategories: Set<String> = []
    @Published var selectedCategoryForPreview: CleanupCategory? = nil
    @Published var selectedFilesByCategory: [String: Set<String>] = [:]
    @Published var isLoadingFiles = false
    @Published var currentCategoryFiles: [CleanupFile] = []
    
   
    private let cleanerService: CleanerService
    private var filesCache: [String: [CleanupFile]] = [:]
    private var displayedFilesCache: [String: [CleanupFile]] = [:]
    private var loadedItemsCount: [String: Int] = [:]
    
   
    private struct Constants {
        static let itemsPerBatch = 100
        static let initialBatchSize = 20
        static let loadMoreThreshold = 10
        static let maxCategoriesInMemory = 3
        static let maxItemsPerCategory = 5000
        static let defaultSelectedCategoryIds = ["app_cache", "web_cache", "trash"]
    }

    init(cleanerService: CleanerService) {
        self.cleanerService = cleanerService
    }

  
    var categories: [CleanupCategory] {
        let allCategories = cleanerService.scanResult?.categories ?? []
        
        return allCategories.sorted { category1, category2 in
            category1.name.localizedCaseInsensitiveCompare(category2.name) == .orderedAscending
        }
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

   
    func isFileSelected(_ filePath: String) -> Bool {
        guard let categoryId = selectedCategoryForPreview?.id else { return false }
        if selectedCategories.contains(categoryId) {
            return true
        }
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
        
        switch newState {
        case .full:
            selectedCategories.insert(categoryId)
            selectedFilesByCategory.removeValue(forKey: categoryId)
        case .none:
            selectedCategories.remove(categoryId)
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
    
    func selectDefaultCategories() {
        selectedCategories.removeAll()
        selectedFilesByCategory.removeAll()
        
        for category in categories {
            if Constants.defaultSelectedCategoryIds.contains(category.id) {
                if category.canAccess && category.size > 0 {
                    selectedCategories.insert(category.id)
                }             }
        }
        
    }
}

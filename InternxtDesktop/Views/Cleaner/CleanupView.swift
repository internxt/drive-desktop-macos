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

struct CleanupView: View {
    @ObservedObject private var viewModel: CleanupViewModel
    @StateObject var cleanerService: CleanerService
    @State private var isInitialized = false
    @State private var showingHelperAlert = false
    @State private var helperStatus: CleanerService.HelperStatusType?
    @State private var showModalConfirmCleanup = false
    @State private var waitingForPermission = false
    

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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard waitingForPermission else { return }
            Task {
                await recheckPermissionAfterSettings()
            }
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
                if status.shouldShowSystemSettings {
                    waitingForPermission = true
                }
            }
            return
        }
        
        await cleanerService.scanCategories()
        viewModel.selectDefaultCategories()
    }
    
    private func recheckPermissionAfterSettings() async {
        let status = await cleanerService.getHelperStatus()
     
        if status == .enabled {
            await MainActor.run {
                waitingForPermission = false
                showingHelperAlert = false
                cleanerService.state = .idle
                cleanerService.resetConnection()
            }
            await cleanerService.scanCategories()
            viewModel.selectDefaultCategories()
        } else if status.isError {
            await MainActor.run {
                helperStatus = status
                if !status.shouldShowSystemSettings {
                    waitingForPermission = false
                }
            }
        }
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
                HStack(spacing: 0) {
                    Spacer()
                    
                    fileListView
                        .frame(width: 400)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
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
            
            AppButton(title: "CLEANER_CLEAN_UP") {
                Task {
                    let status = await cleanerService.getHelperStatus()
                    if status.isError {
                        await MainActor.run {
                            helperStatus = status
                            showingHelperAlert = true
                            if status.shouldShowSystemSettings {
                                waitingForPermission = true
                            }
                        }
                    } else {
                        await MainActor.run {
                            self.showModalConfirmCleanup = true
                        }
                    }
                }
            }
            .disabled(!viewModel.hasAnySelections || cleanerService.isScanning || cleanerService.isCleaning)
            .padding(.bottom, 20)
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

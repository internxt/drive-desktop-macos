//
//  AntivirusTabView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 17/1/25.
//

import SwiftUI

enum ScanState: Equatable {
    case locked
    case options
    case scanning
    case results(noThreats: Bool)
}

struct AntivirusTabView: View {
    @StateObject var viewModel: AntivirusManager
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedPath: String? = nil
    @State private var isModalPresented = false
    @State private var showModalRemove = false
    @State private var showModalCancel = false
    @State private var showCancelConfirmation = false
    
    var body: some View {
        ZStack{
            VStack (alignment: .leading){
                switch viewModel.currentState {
                case .locked:
                    lockedView
                case .options:
                    optionsView
                case .scanning:
                    scanningView
                case .results(let noThreats):
                    resultsView(noThreats: noThreats)
                }
            }
            .padding(20)
            .animation(.easeInOut, value: viewModel.currentState)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $isModalPresented) {
                FileSelectionView(files: viewModel.infectedFiles,onClose: {files in
                    viewModel.infectedFiles = files
                    isModalPresented = false
                    self.showModalCancel = true
                }, onConfirm: { files in
                    viewModel.infectedFiles = files
                    isModalPresented = false
                    self.showModalRemove = true
                    
                })
            }
            if showModalRemove {
                CustomModalView(
                    title: "ANTIVIRUS_MODAL_TITLE_REMOVE",
                    message: "ANTIVIRUS_MODAL_DESCRIPTION_REMOVE",
                    cancelTitle: "COMMON_CANCEL",
                    confirmTitle: "ANTIVIRUS_MODAL_COMMON_REMOVE",
                    confirmColor: .red,
                    onCancel: {
                        self.showModalRemove = false
                        viewModel.currentState = .options
                    },
                    onConfirm: {
                        userConfirmedRemove()
                        self.showModalRemove = false
                        
                    }
                )
            }
            
            if showModalCancel {
                CustomModalView(
                    title: "ANTIVIRUS_MODAL_TITLE_CANCEL",
                    message: "ANTIVIRUS_MODAL_DESCRIPTION_CANCEL",
                    cancelTitle: "COMMON_CANCEL",
                    confirmTitle: "ANTIVIRUS_MODAL_COMMON_REMOVE",
                    confirmColor: .blue,
                    onCancel: {
                        self.showModalCancel = false
                        viewModel.currentState = .options
                    },
                    onConfirm: {
                        userConfirmedRemove()
                        self.showModalCancel = false
                    }
                )
            }
        }
        .alert(isPresented: $showCancelConfirmation) {
            Alert(
                title: Text("ANTIVIRUS_CANCEL_SCAN"),
                message: Text("ANTIVIRUS_CANCEL_SCAN_MESSAGE"),
                primaryButton: .destructive(Text("ANTIVIRUS_CANCEL_SCAN")) {
                    viewModel.cancelScan()
                },
                secondaryButton: .cancel(Text("ANTIVIRUS_CANCEL_SCAN_CONTINUE"))
            )
        }

    }
    
    
    var lockedView: some View {
        VStack(spacing: 15) {
            AppText("FEATURE_LOCKED")
                .font(.BaseMedium)
                .foregroundColor(.Gray100)
            
            
            AppText("GENERAL_UPGRADE_PLAN")
                .font(.SMRegular)
                .foregroundColor(.Gray80)
            
            AppButton(title: "COMMON_UPGRADE", onClick: {
                URLDictionary.UPGRADE_PLAN.open()
            })
            VStack(spacing: 15) {
                
                scanOptionRow(title: "ANTIVIRUS_SYSTEM_SCAN", buttonTitle: "ANTIVIRUS_START_SCAN",isEnabled: false) {
                    
                }
                scanOptionRow(title: "ANTIVIRUS_CUSTOM_SCAN" , buttonTitle: "ANTIVIRUS_CHOOSE_FILES" , isEnabled: false) {
                    
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        
    }
    
    var optionsView: some View {
        VStack(spacing: 15) {
            
            scanOptionRow(title: "ANTIVIRUS_SYSTEM_SCAN", buttonTitle: "ANTIVIRUS_START_SCAN") {
                if let url = BookmarkManager.shared.resolveBookmark() {
                    self.selectedPath = url.path
                    viewModel.selectedPath = url.path
                    viewModel.startScan(path: url.path)
                } else {
                    showUserDirectory()
                }
                
            }
            scanOptionRow(title: "ANTIVIRUS_CUSTOM_SCAN", buttonTitle: "ANTIVIRUS_CHOOSE_FILES") {
                selectFileOrFolder { url in
                    guard let url = url else {
                        appLogger.error("incorrect url")
                        return
                    }
                    selectedPath = url.path
                    viewModel.selectedPath = url.path
                    viewModel.startScan(path: url.path)
                    
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    func selectFileOrFolder(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select"
        openPanel.level = .modalPanel
        
        openPanel.begin { result in
            if result == .OK {
                completion(openPanel.url)
            } else {
                completion(nil)
            }
        }
    }
    
    var scanningView: some View {
        VStack(spacing: 20) {
            AppText("ANTIVIRUS_SCANNING")
                .font(.BaseMedium)
                .foregroundColor(.Gray100)
            
            
            AppText(viewModel.selectedPath)
                 .font(.SMRegular)
                 .foregroundColor(.Gray80)
                 .lineLimit(2)
                 .truncationMode(.tail)
                 .frame(maxWidth: .infinity)
                 .frame(height: 40)
            
            ProgressView(value: min(viewModel.progress, 100) / 100.0)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .animation(.easeInOut, value: viewModel.progress)
       
            AppText("\(Int(viewModel.progress))%")
                .font(.SMMedium)
                .foregroundColor(.Gray80)
            
            AppButton(title: "ANTIVIRUS_CANCEL_SCAN", onClick: {
                self.showCancelConfirmation = true
            })
            
            HStack {
                scanDetail(title: "ANTIVIRUS_SCANNED_FILES", value: viewModel.scannedFiles)
                Divider()
                    .frame(height: 40)
                    .padding(.horizontal,24)
                scanDetail(title: "ANTIVIRUS_DETECTED_FILES", value: viewModel.detectedFiles)
            }.padding()
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? Color("Gray5") :  Color("Surface"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("Gray10"), lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
        
    }
    
    func resultsView(noThreats: Bool) -> some View {
        VStack(spacing: 12) {
            if noThreats {
                Image("antivirusShield")
                    .resizable()
                    .foregroundColor(.green)
                    .frame(width: 50, height: 50)
                
                AppText("ANTIVIRUS_NO_THREATS_FOUND")
                    .font(.BaseMedium)
                    .foregroundColor(.Gray100)
                
                AppText("ANTIVIRUS_NO_FURTHER_ACTIONS")
                    .font(.SMRegular)
                    .foregroundColor(.Gray80)
                    .padding(.bottom,20)
                
                
                AppButton(title: "ANTIVIRUS_SCAN_AGAIN",onClick: {
                    viewModel.currentState = .options
                },size: .SM)
                
            } else {
                Image("antivirusShieldRed")
                    .resizable()
                    .foregroundColor(.red)
                    .frame(width: 50, height: 50)
                
                AppText("ANTIVIRUS_MALWARE_DETECTED")
                    .font(.BaseMedium)
                    .foregroundColor(.Gray100)
                
                AppText("ANTIVIRUS_REVIEW_REMOVE_THREATS")
                    .font(.SMRegular)
                    .foregroundColor(.Gray80)
                
                AppButton(title: "ANTIVIRUS_REMOVE_MALWARE",onClick: {
                    self.isModalPresented = true
                },size: .SM)
                .padding(.bottom,20)
            }
            
            HStack {
                scanDetail(title: "ANTIVIRUS_SCANNED_FILES", value: viewModel.scannedFiles)
                Divider()
                    .frame(height: 40)
                    .padding(.horizontal,24)
                scanDetail(title: "ANTIVIRUS_DETECTED_FILES", value: viewModel.detectedFiles)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(colorScheme == .dark ? Color("Gray5") :  Color("Surface"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("Gray10"), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }
    
    func scanOptionRow(title: String, buttonTitle: String, isEnabled: Bool = true,action: @escaping () -> Void) -> some View {
        HStack {
            AppText(title)
                .font(.SMMedium)
                .foregroundColor(.Gray80)
            Spacer()
            AppButton(title: buttonTitle,onClick: {
                action()
            },size: .SM,isEnabled: isEnabled)
            
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    func scanDetail(title: String, value: Int) -> some View {
        VStack {
            AppText("\(value)")
                .font(.BaseMedium)
                .foregroundColor(.Gray100)
            
            AppText(title)
                .font(.SMRegular)
                .foregroundColor(.Gray80)
        }
    }
    
    func userConfirmedRemove() {
        let selectedInfected = viewModel.infectedFiles.filter { $0.isSelected }
        if selectedInfected.count == 0 {
            self.showAlert(message: "ANTIVIRUS_NO_FILES_SELECTED")
            self.viewModel.currentState = .options
            return
        }
        do {
            try viewModel.removeInfectedFiles(selectedInfected)
            viewModel.currentState = .options
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain,
               error.code == CocoaError.fileWriteNoPermission.rawValue {
                appLogger.error(error.localizedDescription)
                showAlert(message: error.localizedDescription, style: .warning)
            } else {
                appLogger.error(error.localizedDescription)
                showAlert(message: error.localizedDescription, style: .warning)
            }
        }
    }
    
    func showAlert(message: String, informativeText: String? = nil, style: NSAlert.Style = .informational, buttonTitle: String = "OK") {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString(message, comment: "")
        alert.informativeText = informativeText ?? ""
        alert.alertStyle = style
        alert.addButton(withTitle: buttonTitle)
        alert.runModal()
    }
    


    func selectUserFolder(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Your User Folder"
        openPanel.prompt = "Select"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = URL(fileURLWithPath: "/Users/\(NSUserName())")
        openPanel.level = .modalPanel
        
        openPanel.begin { result in
            if result == .OK {
                completion(openPanel.url)
            } else {
                completion(nil)
            }
        }
    }

    func showUserDirectory() {
        selectUserFolder { url in
            guard let url = url else {
                appLogger.info("No folder selected.")
                return
            }
            
            let userHomeDirectory = "/Users/\(NSUserName())"
            
            if url.path == userHomeDirectory {
                do {
                    try BookmarkManager.shared.saveBookmark(url: url)
                    appLogger.info("Bookmark saved.")
                    selectedPath = url.path
                    viewModel.selectedPath = url.path
                    if let resolvedURL = BookmarkManager.shared.resolveBookmark() {
                        viewModel.startScan(path: resolvedURL.path)
                    } else {
                        appLogger.error("cannot get url")
                    }
                } catch {
                    appLogger.error("Error saving bookmark: \(error)")
                }
            } else {
                appLogger.error("Incorrect folder selected: \(url.path)")
                self.showAlert(message: "You must select your user folder \(NSUserName())")
                showUserDirectory()
            }
        }
    }


    

}

struct AntivirusTabView_Previews: PreviewProvider {
    static var previews: some View {
        AntivirusTabView(viewModel: AntivirusManager())
    }
}






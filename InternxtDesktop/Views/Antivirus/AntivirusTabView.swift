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
                FileSelectionView(onClose: {
                    isModalPresented = false
                    self.showModalCancel = true
                }, onConfirm: {
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
                    },
                    onConfirm: {
                        // delete files
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
                    },
                    onConfirm: {
                      // delete files
                    }
                )
            }
        }
        .onAppear{
            Task {
                await viewModel.fetchAntivirusStatus()
            }
            
        }
    }
    
    
    var lockedView: some View {
        VStack(spacing: 15) {
            AppText("ANTIVIRUS_FEATURE_LOCKED")
                .font(.BaseMedium)
                .foregroundColor(.Gray100)
            
            
            AppText("ANTIVIRUS_UPGRADE_PLAN")
                .font(.SMRegular)
                .foregroundColor(.Gray80)
            
            AppButton(title: "COMMON_UPGRADE", onClick: {
                viewModel.currentState = .options
            })
            VStack(spacing: 15) {
                
                scanOptionRow(title: "ANTIVIRUS_SYSTEM_SCAN", buttonTitle: "ANTIVIRUS_START_SCAN",isEnabled: false) {
                    
                }
                scanOptionRow(title: "ANTIVIRUS_SYSTEM_SCAN", buttonTitle: "ANTIVIRUS_CHOOSE_FILES" , isEnabled: false) {
                    
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        
    }
    
    var optionsView: some View {
        VStack(spacing: 15) {
            
            scanOptionRow(title: "ANTIVIRUS_SYSTEM_SCAN", buttonTitle: "ANTIVIRUS_START_SCAN") {
                viewModel.startScan()
            }
            scanOptionRow(title: "ANTIVIRUS_SYSTEM_SCAN", buttonTitle: "ANTIVIRUS_CHOOSE_FILES") {
                selectFileOrFolder { url in
                    if let url = url {
                        selectedPath = url.path
                        print("File: \(url.path)")
                    }
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
            
            
            AppText("/Users/joe/Desktop/my_files/virus.dmg")
                .font(.SMRegular)
                .foregroundColor(.Gray80)
            
            
            ProgressView(value: viewModel.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            AppText("\(Int(viewModel.progress * 100))%")
                .font(.SMMedium)
                .foregroundColor(.Gray80)
            
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
}

struct AntivirusTabView_Previews: PreviewProvider {
    static var previews: some View {
        AntivirusTabView(viewModel: AntivirusManager())
    }
}






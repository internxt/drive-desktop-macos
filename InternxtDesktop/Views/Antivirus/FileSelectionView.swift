//
//  FileSelectionView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 21/1/25.
//

import SwiftUI

struct FileItem: Identifiable {
    let id = UUID()
    let iconName: String
    let fileName: String
    let extensionType: String
    var isSelected: Bool = false
    let fullPath: String 
}

struct FileSelectionView: View {
    @State var files: [FileItem] 
    @State private var selectAll = false
    @Environment(\.colorScheme) var colorScheme
    @State private var showModal1 = false
    @State private var showModal2 = false
    let onClose: ([FileItem]) -> Void
    let onConfirm: ([FileItem]) -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color.Gray1 : Color.white)
                .shadow(radius: 10)
            
            VStack(spacing: 20) {
                HStack {
                    AppText("ANTIVIRUS_FILES_CONTAINING_MALWARE")
                        .font(.LGMedium)
                        .foregroundColor(.Gray100)
                    
                    Spacer()
                    
                    AppText("Selected \(files.filter { $0.isSelected }.count) out of \(files.count)")
                        .font(.BaseRegular)
                        .foregroundColor(.Gray50)
                    
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                HStack {
                    Toggle(isOn: $selectAll) {
                        AppText("Select all")
                            .font(.BaseMedium)
                            .foregroundColor(.Gray100)
                    }
                    .onChange(of: selectAll) { value in
                        files = files.map { file in
                               var updatedFile = file
                               updatedFile.isSelected = value
                               return updatedFile
                           }
                        
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                VStack {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(files.indices, id: \.self) { index in
                                HStack {
                                    Image(systemName: files[index].isSelected ? "checkmark.square.fill" : "square")
                                        .foregroundColor(.blue)
                                        .onTapGesture {
                                            files[index].isSelected.toggle()
                                             selectAll = files.allSatisfy { $0.isSelected }
                                        }

                                    Image(files[index].iconName)
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(.green)
                                        .padding(.trailing, 10)

                                    VStack(alignment: .leading) {
                                        AppText("\(files[index].fileName)")
                                            .font(.LGRegular)
                                            .foregroundColor(.Gray80)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(colorScheme == .dark ? Color.gray : Color.gray.opacity(0.5), lineWidth: 1)
                        .background(colorScheme == .dark ? Color.Gray1 : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                )
                .padding(.horizontal, 20)
                .frame(height: 250)
                
                
            
                HStack {
                    Spacer()
                    AppButton(title: "COMMON_CANCEL", onClick: {
                        withAnimation {
                            let selectedFiles = files.filter { $0.isSelected }
                            onClose(selectedFiles)
                        }
                    }, type: .secondary, size: .MD)
                    AppButton(title: "ANTIVIRUS_MODAL_COMMON_REMOVE", onClick: {
                        let selectedFiles = files.filter { $0.isSelected }
                        onConfirm(selectedFiles)
                    }, type: .primary, size: .MD ,isEnabled: files.contains { $0.isSelected })
                    
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

        }
        .frame(width: 500, height: 450)
    }
}

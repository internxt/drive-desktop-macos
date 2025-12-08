//
//  DeviceNameView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/9/23.
//

import SwiftUI

struct DeviceNameView: View {
    @State private var isEditingDeviceName: Bool = false
    var body: some View {
        let deviceName = ConfigLoader().getDeviceName()
        
        
        if let deviceNameUnwrapped = deviceName {
            VStack(alignment: .center, spacing: 6) {
                VStack {
                    AppText(deviceNameUnwrapped).font(.LGMedium)
                        .accessibilityIdentifier("deviceNameUser")
                }.frame(height: 36)
                /* if isEditingDeviceName {
                    HStack {
                        AppButton(title: "Cancel", onClick: {
                            isEditingDeviceName = false
                        }, type: .secondaryWhite, size: .MD)
                        AppButton(title: "Save", onClick: handleSaveEditedName, type: .primary, size: .MD)
                    }
                } else {
                    AppButton(title: "Edit", onClick: {
                        isEditingDeviceName = true
                    }, type: .secondaryWhite, size: .MD)
                }*/
                
            }
            
        } else {
            VStack { EmptyView() }
        }
    }
    
    func handleSaveEditedName() {
        
    }
}

struct DeviceNameView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceNameView()
    }
}

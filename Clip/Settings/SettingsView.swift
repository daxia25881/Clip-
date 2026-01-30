//
//  SettingsView.swift
//  Clip
//
//  Created by Antigravity on 1/26/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import ClipKit

struct SettingsView: View {
    @AppStorage("historyLimit", store: .shared) var historyLimitRaw: Int = 25
    @AppStorage("showLocationIcon", store: .shared) var showLocationIcon: Bool = true
    @AppStorage("showClipboardNotification", store: .shared) var showClipboardNotification: Bool = true
    @AppStorage("showCloudNotification", store: .shared) var showCloudNotification: Bool = true
    
    // Custom paths
    @AppStorage("snippetTargetPath", store: .shared) var copylogPath: String = ""
    @AppStorage("barkPath", store: .shared) var barkPath: String = ""
    @AppStorage("webdavURL", store: .shared) var webdavURL: String = ""
    @AppStorage("webdavUsername", store: .shared) var webdavUsername: String = ""
    @AppStorage("webdavPassword", store: .shared) var webdavPassword: String = ""
    
    // Environment to dismiss the view
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker(selection: $historyLimitRaw, label: EmptyView()) {
                        Text("10 items").tag(10)
                        Text("25 items").tag(25)
                        Text("50 items").tag(50)
                        Text("100 items").tag(100)
                    }
                    .pickerStyle(InlinePickerStyle())
                } header: {
                    Text("Items")
                }
                
                Section {
                    Toggle("Show Location Icons", isOn: $showLocationIcon)
                        .onChange(of: showLocationIcon) { _ in
                            postSettingsChanged()
                        }
                }
                
                Section {
                    Toggle("Clipboard Notification", isOn: $showClipboardNotification)
                    Toggle("Cloud Notification", isOn: $showCloudNotification)
                }
                
                Section {
                    HStack {
                        Text("Copylog路径")
                        Spacer()
                        TextField("Enter path...", text: $copylogPath)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Bark路径")
                        Spacer()
                        TextField("Enter address...", text: $barkPath)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("webdav地址")
                        Spacer()
                        TextField("Enter URL...", text: $webdavURL)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("用户名")
                        Spacer()
                        TextField("Enter username...", text: $webdavUsername)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("密码")
                        Spacer()
                        SecureField("Enter password...", text: $webdavPassword)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .preferredColorScheme(.dark)
    }
    
    private func postSettingsChanged() {
        NotificationCenter.default.post(name: Notification.Name("SettingsDidChangeNotification"), object: nil)
    }
}

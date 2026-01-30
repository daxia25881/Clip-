//
//  SettingsViewController.swift
//  Clip
//
//  Created by Riley Testut on 6/14/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

import ClipKit

extension SettingsViewController
{
    private enum Section: Int, CaseIterable
    {
        case historyLimit
        case location
    }
    
    private enum CustomRow: Int, CaseIterable
    {
        case targetPath
        case barkPath
        case webdavURL
        case webdavUsername
        case webdavPassword
        
        var title: String {
            switch self {
            case .targetPath: return NSLocalizedString("CopyLog路径", comment: "")
            case .barkPath: return NSLocalizedString("Bark路径", comment: "")
            case .webdavURL: return NSLocalizedString("WebDav地址", comment: "")
            case .webdavUsername: return NSLocalizedString("用户名", comment: "")
            case .webdavPassword: return NSLocalizedString("密码", comment: "")
            }
        }
    }
    
    private enum NotificationRow: Int, CaseIterable
    {
        case clipboardNotification
        case cloudNotification
        
        var title: String {
            switch self {
            case .clipboardNotification: return NSLocalizedString("Clipboard Notification", comment: "")
            case .cloudNotification: return NSLocalizedString("Cloud Notification", comment: "")
            }
        }
    }
    
    static let settingsDidChangeNotification: Notification.Name = Notification.Name("SettingsDidChangeNotification")
}

class SettingsViewController: UITableViewController
{
    @IBOutlet private var showLocationIconSwitch: UISwitch!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.showLocationIconSwitch?.isOn = UserDefaults.shared.showLocationIcon
        
        // Add custom settings in the footer to avoid breaking the static storyboard layout
        self.setupCustomSettingsFooter()
    }
    
    private func setupCustomSettingsFooter()
    {
        let containerView = UIView()
        let width = self.tableView.bounds.width
        containerView.frame = CGRect(x: 0, y: 0, width: width, height: 460)
        
        // NOTIFICATION CONFIGURATION Section
        let notificationSectionHeader = UILabel()
        notificationSectionHeader.text = NSLocalizedString("NOTIFICATION CONFIGURATION", comment: "").uppercased()
        notificationSectionHeader.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        notificationSectionHeader.textColor = UIColor.lightGray
        notificationSectionHeader.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(notificationSectionHeader)
        
        let notificationStackView = UIStackView()
        notificationStackView.axis = .vertical
        notificationStackView.spacing = 1
        notificationStackView.backgroundColor = UIColor.separator
        notificationStackView.layer.cornerRadius = 10
        notificationStackView.clipsToBounds = true
        notificationStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(notificationStackView)
        
        // Match system margins
        containerView.layoutMargins = self.tableView.layoutMargins
        
        NSLayoutConstraint.activate([
            notificationSectionHeader.leadingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.leadingAnchor, constant: 16),
            notificationSectionHeader.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            
            notificationStackView.leadingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.leadingAnchor),
            notificationStackView.trailingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.trailingAnchor),
            notificationStackView.topAnchor.constraint(equalTo: notificationSectionHeader.bottomAnchor, constant: 8)
        ])
        
        for row in NotificationRow.allCases
        {
            let rowView = UIView()
            rowView.backgroundColor = UIColor.secondarySystemGroupedBackground
            rowView.translatesAutoresizingMaskIntoConstraints = false
            rowView.heightAnchor.constraint(equalToConstant: 44).isActive = true
            
            let label = UILabel()
            label.text = row.title
            label.font = UIFont.systemFont(ofSize: 17)
            label.translatesAutoresizingMaskIntoConstraints = false
            rowView.addSubview(label)
            
            let toggle = UISwitch()
            toggle.tag = row.rawValue
            toggle.addTarget(self, action: #selector(toggleNotification(_:)), for: .valueChanged)
            toggle.translatesAutoresizingMaskIntoConstraints = false
            rowView.addSubview(toggle)
            
            switch row
            {
            case .clipboardNotification: toggle.isOn = UserDefaults.shared.showClipboardNotification
            case .cloudNotification: toggle.isOn = UserDefaults.shared.showCloudNotification
            }
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 16),
                label.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
                
                toggle.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -16),
                toggle.centerYAnchor.constraint(equalTo: rowView.centerYAnchor)
            ])
            
            notificationStackView.addArrangedSubview(rowView)
        }
        
        // UPLOAD CONFIGURATION Section
        
        let sectionHeader = UILabel()
        sectionHeader.text = NSLocalizedString("UPLOAD CONFIGURATION", comment: "").uppercased()
        sectionHeader.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        sectionHeader.textColor = UIColor.lightGray
        sectionHeader.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(sectionHeader)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 1
        stackView.backgroundColor = UIColor.separator
        stackView.layer.cornerRadius = 10
        stackView.clipsToBounds = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            sectionHeader.leadingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.leadingAnchor, constant: 16),
            sectionHeader.topAnchor.constraint(equalTo: notificationStackView.bottomAnchor, constant: 30),
            
            stackView.leadingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.layoutMarginsGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: sectionHeader.bottomAnchor, constant: 8)
        ])
        
        for row in CustomRow.allCases
        {
            let rowView = UIView()
            rowView.backgroundColor = UIColor.secondarySystemGroupedBackground
            rowView.translatesAutoresizingMaskIntoConstraints = false
            rowView.heightAnchor.constraint(equalToConstant: 44).isActive = true
            
            let label = UILabel()
            label.text = row.title
            label.font = UIFont.systemFont(ofSize: 17)
            label.translatesAutoresizingMaskIntoConstraints = false
            rowView.addSubview(label)
            
            let textField = UITextField()
            textField.textAlignment = .right
            textField.delegate = self
            textField.tag = row.rawValue
            textField.placeholder = NSLocalizedString("Required", comment: "")
            textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            textField.translatesAutoresizingMaskIntoConstraints = false
            rowView.addSubview(textField)
            
            switch row
            {
            case .targetPath: textField.text = UserDefaults.shared.snippetTargetPath
            case .barkPath: textField.text = UserDefaults.shared.barkPath
            case .webdavURL: textField.text = UserDefaults.shared.webdavURL
            case .webdavUsername: textField.text = UserDefaults.shared.webdavUsername
            case .webdavPassword: 
                textField.text = UserDefaults.shared.webdavPassword
                textField.isSecureTextEntry = true
            }
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 16),
                label.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
                
                textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 16),
                textField.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -16),
                textField.topAnchor.constraint(equalTo: rowView.topAnchor),
                textField.bottomAnchor.constraint(equalTo: rowView.bottomAnchor)
            ])
            
            stackView.addArrangedSubview(rowView)
        }
        
        self.tableView.tableFooterView = containerView
    }
}

private extension SettingsViewController
{
    @IBAction func toggleShowLocationIcon(_ sender: UISwitch)
    {
        UserDefaults.shared.showLocationIcon = sender.isOn
        NotificationCenter.default.post(name: SettingsViewController.settingsDidChangeNotification, object: nil)
    }
    
    @objc func textFieldDidChange(_ textField: UITextField)
    {
        guard let row = CustomRow(rawValue: textField.tag) else { return }
        switch row
        {
        case .targetPath: 
            var path = textField.text ?? ""
            if path.hasSuffix("/") {
                path = String(path.dropLast())
            }
            UserDefaults.shared.snippetTargetPath = path
        case .barkPath: UserDefaults.shared.barkPath = textField.text
        case .webdavURL: UserDefaults.shared.webdavURL = textField.text
        case .webdavUsername: UserDefaults.shared.webdavUsername = textField.text
        case .webdavPassword: UserDefaults.shared.webdavPassword = textField.text
        }
    }
    
    @objc func toggleNotification(_ sender: UISwitch)
    {
        guard let row = NotificationRow(rawValue: sender.tag) else { return }
        switch row
        {
        case .clipboardNotification: UserDefaults.shared.showClipboardNotification = sender.isOn
        case .cloudNotification: UserDefaults.shared.showCloudNotification = sender.isOn
        }
    }
}

extension SettingsViewController: UITextFieldDelegate
{
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        switch Section.allCases[indexPath.section]
        {
        case .historyLimit:
            let limit = HistoryLimit.allCases[indexPath.row]
            cell.accessoryType = (limit == UserDefaults.shared.historyLimit) ? .checkmark : .none
            
        case .location: break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard Section.allCases[indexPath.section] == .historyLimit else { return }
        
        let historyLimit = HistoryLimit.allCases[indexPath.row]
        UserDefaults.shared.historyLimit = historyLimit
        
        tableView.reloadData()
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        textField.resignFirstResponder()
        return true
    }
}

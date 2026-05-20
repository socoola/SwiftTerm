//
//  MainTabView.swift
//  iOSTerminal
//

import SwiftUI
import UIKit

class TabBarController: UITabBarController {
    private var store = ServerStore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Tab Bar 样式
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = UIColor(red: 0.17, green: 0.47, blue: 0.50, alpha: 1.0)
        
        // 创建三个 Tab
        let serverVC = createTab(
            view: ServerListView().environmentObject(store),
            title: "服务器",
            imageName: "server.rack",
            tag: 0
        )
        
        let quickConnectVC = createTab(
            view: QuickConnectView(),
            title: "快速连接",
            imageName: "bolt.horizontal",
            tag: 1
        )
        
        let settingsVC = createTab(
            view: SettingsTabView(),
            title: "设置",
            imageName: "gear",
            tag: 2
        )
        
        viewControllers = [serverVC, quickConnectVC, settingsVC]
        selectedIndex = 0
    }
    
    private func createTab<T: View>(
        view: T,
        title: String,
        imageName: String,
        tag: Int
    ) -> UIViewController {
        let hosting = UIHostingController(rootView: view)
        hosting.title = title
        hosting.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: imageName),
            tag: tag
        )
        let nav = UINavigationController(rootViewController: hosting)
        return nav
    }
}

// Settings wrapper without dismiss button for tab usage
struct SettingsTabView: View {
    var body: some View {
        SettingsView()
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
    }
}

// Quick connect wrapper
struct QuickConnectView: View {
    var body: some View {
        SSHLoginView()
            .navigationTitle("快速连接")
            .navigationBarTitleDisplayMode(.large)
    }
}

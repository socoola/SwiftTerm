//
//  ViewController.swift
//  SwiftTerm
//
//  Created by Miguel de Icaza on 3/19/19.
//  Copyright © 2019 Miguel de Icaza. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    private var tabController: TabBarController?

    override func viewDidLoad() {
        super.viewDidLoad()

        let tabBarController = TabBarController()
        addChild(tabBarController)
        view.addSubview(tabBarController.view)
        tabBarController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tabBarController.view.topAnchor.constraint(equalTo: view.topAnchor),
            tabBarController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tabBarController.didMove(toParent: self)
        tabController = tabBarController
    }
}

//
//  Item2ViewController.swift
//  iOS Example
//
//  Created by Jason Prasad on 3/8/16.
//  Copyright © 2016 Routing. All rights reserved.
//

import UIKit

class Item2ViewController: UIViewController {
    
    @IBAction func presentItem3(sender: AnyObject) {
        AppRoutes.sharedRouter.open("routingexample://presentitem3/Item2")
    }
    
    @IBAction func showItem3(sender: AnyObject) {
        AppRoutes.sharedRouter.open("routingexample://showitem3/Item2")
    }

}

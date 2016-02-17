//
//  AppRoutes.swift
//  Example
//
//  Created by Jason Prasad on 1/29/16.
//  Copyright © 2016 Routing. All rights reserved.
//

import Foundation
import Routing

public struct AppRoutes {
    
    public static let paths = Paths()
    public static let urls = URLs()
    
    public static let host = "routingexample://"
    public static let root = "root"
    public static let first = "first"
    public static let second = "second"
    
    public struct Paths {
        public let root = "\(host)\(AppRoutes.root)"
        public let first = "\(host)\(AppRoutes.root)/\(AppRoutes.first)"
        public let second = "\(host)\(AppRoutes.root)/\(AppRoutes.second)"
    }
    
    public struct URLs {
        public let root = NSURL(string: AppRoutes.paths.root)!
        public let first = NSURL(string: AppRoutes.paths.first)!
        public let second = NSURL(string: AppRoutes.paths.second)!
    }
    
}

internal extension Routing {
    
    static var sharedRouter = { Routing() }()
    static var isProxying = false
    
    internal func registerRoutes() {
        
        Routing.sharedRouter.proxy(AppRoutes.paths.first) { (var route, parameters, next) in
            if Routing.isProxying { route = AppRoutes.paths.second }
            next(route, parameters)
        }
        
        Routing.sharedRouter.map(AppRoutes.paths.first,
            controller: FirstViewController.self,
            inNavigationController: true) { parameters in
                let storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle())
                let vc = storyboard.instantiateViewControllerWithIdentifier(AppRoutes.first)
                return UINavigationController(rootViewController: vc)
        }
        
        Routing.sharedRouter.map(AppRoutes.paths.first) { (parameters, completed) in
            guard let window = UIApplication.sharedApplication().delegate?.window else {
                completed()
                return
            }
            
            let storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle())
            let vc = storyboard.instantiateViewControllerWithIdentifier(AppRoutes.first)
            let navController = UINavigationController(rootViewController: vc)
            let animated: Bool = parameters["animated"] == nil || parameters["animated"] == "true"
            window?.rootViewController?.presentViewController(navController, animated: animated, completion: completed)
        }
        
        Routing.sharedRouter.proxy(AppRoutes.paths.second) { (var route, parameters, next) in
            if Routing.isProxying { route = AppRoutes.paths.first }
            next(route, parameters)
        }
        
        Routing.sharedRouter.map(AppRoutes.paths.second) { (parameters, completed) in
            guard let window = UIApplication.sharedApplication().delegate?.window else {
                completed()
                return
            }
            
            let storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle())
            let vc = storyboard.instantiateViewControllerWithIdentifier(AppRoutes.second)
            let animated: Bool = parameters["animated"] == nil || parameters["animated"] == "true"
            
            CATransaction.begin()
            CATransaction.setCompletionBlock(completed)
            if let presented = (window?.rootViewController?.presentedViewController as? UINavigationController) {
                presented.pushViewController(vc, animated: animated)
            } else {
                (window?.rootViewController as? UINavigationController)?.pushViewController(vc, animated: animated)
            }
            CATransaction.commit()
        }
        
        Routing.sharedRouter.proxy("/*") {  route, parameters, next in
            print("Routing route: \(route) with parameters: \(parameters)")
            next(nil, nil)
        }
    
    }
    
}



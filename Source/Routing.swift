//
//  Routing.swift
//  Routing
//
//  Created by Jason Prasad on 9/28/15.
//  Copyright © 2015 Routing. All rights reserved.
//

import Foundation

public final class Routing {
    
    public typealias Parameters = [String: String]
    
    /**
     The closure type associated with #map
     
     - Parameter Parameters:  Any query parameters or dynamic segments found in the URL
     - Parameter Completed: Must be called for Routing to continue processing other routes with #open
     */
    
    public typealias MapHandler = (Parameters, Completed) -> Void
    public typealias Completed = () -> Void
    
    /**
     The closure type associated with #proxy
     
     - Parameter String:  The route being opened
     - Parameter Parameters:  Any query parameters or dynamic segments found in the URL
     - Parameter Next: Must be called for Routing to continue processing. Calling #Next with
     nil arguments will continue executing other matching proxies. Calling #Next with non nil
     arguments will continue to process the route.
     */
    
    public typealias ProxyHandler = (String, Parameters, Next) -> Void
    public typealias Next = (String?, Parameters?) -> Void
    
    private var accessQueue: dispatch_queue_t!
    private var routingQueue: dispatch_queue_t!
    private var callbackQueue: dispatch_queue_t!
    private typealias Map = (String) -> (MapHandler?, Parameters)
    private var maps: [Map] = [Map]()
    private typealias Proxy = (String) -> (ProxyHandler?, Parameters)
    private var proxies: [Proxy] = [Proxy]()
    
    /**
     Intializes a Routing instance with specific queues for its behavior
     
     - Parameter accessQueue:  The queue for protecting its internal read and writes
     - Parameter routingQueue:  The queue for looking up and executing mapped routes and proxies
     - Parameter callbackQueue:  The queue to call the closure associated with the route or proxy
     */
    
    public init(accessQueue: dispatch_queue_t = dispatch_queue_create("Routing Access Queue", DISPATCH_QUEUE_CONCURRENT),
        routingQueue: dispatch_queue_t = dispatch_queue_create("Routing Queue", DISPATCH_QUEUE_SERIAL),
        callbackQueue: dispatch_queue_t = dispatch_get_main_queue()) {
            self.accessQueue = accessQueue
            self.routingQueue = routingQueue
            self.callbackQueue = callbackQueue
    }
    
    /**
     Associates a closure to a string pattern. A Routing instance will execute the closure in the event of a matching URL using #open.
     Routing will only execute the first matching mapped route. This will be the last routed added with #map.
     
     ```code
     let router = Routing()
     router.map("routing://route") { parameters, completed in
        completed() // Must call completed or the router will halt!
     }
     ```
     
     - Parameter pattern:  A String pattern
     - Parameter handler:  A MapHandler
     */
    
    public func map(pattern: String, handler: MapHandler) -> Void {
        dispatch_barrier_async(accessQueue) {
            self.maps.insert(self.prepare(pattern, handler: handler), atIndex: 0)
        }
    }
    
    /**
     Associates a closure to a string pattern. A Routing instance will execute the closure in the event of a matching URL using #open.
     Routing will execute all proxies unless #next() is called with non nil arguments.
     
     ```code
     let router = Routing()
     router.proxy("routing://route") { route, parameters, next in
        next(route, parameters) // Must call next or the router will halt!
        /* alternatively, next(nil, nil) allowing additional proxies to execute */
     }
     ```
     
     - Parameter pattern:  A String pattern
     - Parameter handler:  A ProxyHandler
     */
    
    public func proxy(pattern: String, handler: ProxyHandler) -> Void {
        dispatch_barrier_async(accessQueue) {
            self.proxies.insert(self.prepare(pattern, handler: handler), atIndex: 0)
        }
    }
    
    /**
     Will execute the first mapped closure and any proxies with matching patterns. Mapped closures
     are read in a last to be mapped first executed order.
     
     - Parameter URL:  A URL
     - Returns:  A Bool. True if it can open the URL, false otherwise
     */
    
    public func open(URL: NSURL) -> Bool {
        var maps: [Map]!
        var proxies: [Proxy]!
        dispatch_sync(accessQueue) {
            maps = self.maps
            proxies = self.proxies
        }
        
        if maps.count == 0 { return false }
        guard let components = NSURLComponents(URL: URL, resolvingAgainstBaseURL: false) else { return false }
        
        var queryParameters: [String: String] = [:]
        components.queryItems?.forEach() { queryParameters.updateValue(($0.value ?? ""), forKey: $0.name) }
        components.query = nil
        var URLString = components.string ?? ""
        
        if let routeComponents = filterRoute(URLString, routes: maps).first {
            defer {
                dispatch_async(routingQueue) {
                    let semaphore = dispatch_semaphore_create(0)
                    var overwrittingRoute: String?, overwrittingParameters: Parameters?
                    for (handler, var parameters) in self.filterRoute(URLString, routes: proxies) {
                        queryParameters.forEach { parameters[$0.0] = $0.1 }
                        dispatch_async(self.callbackQueue) {
                            handler(URLString, parameters) { (route, parameters) in
                                overwrittingRoute = route
                                overwrittingParameters = parameters
                                dispatch_semaphore_signal(semaphore)
                            }
                        }
                        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
                        if overwrittingRoute != nil || overwrittingParameters != nil { break }
                    }

                    if let (handler, parameters) = (overwrittingRoute.map { self.filterRoute($0, routes: maps).first } ?? routeComponents) {
                        var parameters = parameters
                        (overwrittingParameters ?? queryParameters).forEach { parameters[$0.0] = $0.1 }
                        dispatch_async(self.callbackQueue) { handler(parameters) { dispatch_semaphore_signal(semaphore) } }
                        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
                    }
                }
            }
            return true
        }
        return false
    }
    
    private func filterRoute<H>(route: String, routes: [(String) -> (H?, Parameters)]) -> [(H, Parameters)] {
        return routes
            .map { $0(route) }
            .filter { $0.0 != nil }
            .map { ($0!, $1) }
    }
    
    private func prepare<H>(var pattern: String, handler: H) -> ((String) -> (H?, Parameters)) {
        var dynamicSegments = [String]()
        while let range = pattern.rangeOfString(":[a-zA-Z0-9-_]+", options: [.RegularExpressionSearch, .CaseInsensitiveSearch]) {
            dynamicSegments.append(pattern.substringWithRange(range).stringByReplacingOccurrencesOfString(":", withString: ""))
            pattern.replaceRange(range, with: "([^/]+)")
        }
        
        return { (route: String) -> (H?, Parameters) in
            guard let matches = (try? NSRegularExpression(pattern: pattern, options: .CaseInsensitive))
                .flatMap({ $0.matchesInString(route, options: [], range: NSMakeRange(0, route.characters.count)) })?
                .first
            else {
                return (nil, [:])
            }

            var parameters = Parameters()
            if dynamicSegments.count > 0 && dynamicSegments.count == matches.numberOfRanges - 1 {
                [Int](1 ..< matches.numberOfRanges).forEach { (index) in
                    parameters[dynamicSegments[index-1]] = (route as NSString).substringWithRange(matches.rangeAtIndex(index))
                }
            }
            return (handler, parameters)
        }
    }
    
}

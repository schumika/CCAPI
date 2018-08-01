//
//  ConnectCoreAPI.swift
//  ConnectCore
//
//  Created by Anca Julean on 30/07/2018.
//  Copyright © 2018 alarm.com. All rights reserved.
//

import Foundation

public struct Site : Codable {
    private var name: String
    
    init(siteName: String) {
        self.name = siteName
    }
    
    public func getSiteInfo() -> String {
        return name
    }
}

public protocol LoginDelegate {
    func onResponse(_ success: Bool, _ status: String)
}

public protocol LoadSitesDelegate {
    func onSitesLoaded(_ sites: [Site]?, _ status: String)
}


public class ConnectCoreAPI {
    
    private var username: String?
    private var password: String?
    private var isLoggedIn: Bool = false
    private var sites: [Site]?
    private var authentificationToken: String?
    private var cookie: String?
    
    private static var INSTANCE = ConnectCoreAPI()
    
    private init() {
        setenv("URLSessionCertificateAuthorityInfoFile", "INSECURE_SSL_NO_VERIFY", 1)
    }
    
    public func printData() -> String {
        return "isLoggedIn: \(isLoggedIn)"
    }
    
    public static func getInstance() -> ConnectCoreAPI {
        return INSTANCE
    }
    
    public static func destroyInstance() {
        // Do nothing
    }
    
    private var loginDelegate: LoginDelegate?
    
    public let server = "https://portal-quick.icontroldev.com/ng/"
    
    public func signIn(_ user: String, _ pass: String, _ callback: LoginDelegate) {

        var urlRequest = URLRequest(url: URL(string: "\(server)rest/icontrol/access/login")!,
                                    cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30.0)
        urlRequest.httpMethod = "POST"
        
        loginDelegate = callback

        addCommonHeadersTo(&urlRequest)
        
        urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(user, forHTTPHeaderField: "X-login")

        let encodedPassword = "X-password=\(pass.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.alphanumerics)!)"
        urlRequest.httpBody = encodedPassword.data(using: .utf8)

        let sessionConfiguration = URLSessionConfiguration.default

        let urlSession = URLSession(configuration:sessionConfiguration, delegate: nil, delegateQueue: nil)
        urlSession.dataTask(with: urlRequest, completionHandler: { [weak self] (data, response, error) -> Void in
            if error == nil {
                if let response = response, let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    if statusCode == 200 {
                        self?.username = user
                        self?.password = pass
                        self?.sites = nil

                        if let headerFields = (response as? HTTPURLResponse)?.allHeaderFields {
                            self?.authentificationToken = headerFields["X-token"] as? String
                            self?.cookie = headerFields["Set-Cookie"] as? String
                            self?.isLoggedIn = true
                        }

                    }
                    callback.onResponse((self?.isLoggedIn)!, String("statusCode:\(statusCode)"))
                } else {
                    callback.onResponse((self?.isLoggedIn)!, String("statusCode:\(-1)"))
                }
            } else {
                callback.onResponse((self?.isLoggedIn)!, error!.localizedDescription)
            }
        }).resume()
    }
    
    
    private let commonHeaders = ["Accept-Language":"en-US", "Host":"portal-quick.icontroldev.com", "User-Agent":"iPhone/9.6.0.1 (iPhone; OS 11_4; en-US; x86_64)", "X-appKey":"paZy7AWENega7YV6yTA5y7yvUVEtu4YBate6YZ", "X-appVersion":"iPhone/9.6.0.1", "X-clientType":"ngaiPhone", "X-format":"json", "X-locale":"en_US", "X-version":"5.0"]
    
    private func addCommonHeadersTo(_ urlRequest: inout URLRequest) {
        for (key, value) in commonHeaders {
            urlRequest.addValue(value, forHTTPHeaderField: key)
        }
    }
    
    public func getSitesList(_ callback: LoadSitesDelegate) {
        if isLoggedIn {
            
            var urlRequest = URLRequest(url: URL(string: "\(server)rest/icontrol/ui/updates")!,
                                        cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30.0)
            urlRequest.httpMethod = "GET"
            
            addCommonHeadersTo(&urlRequest)
            
            urlRequest.addValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue(cookie!, forHTTPHeaderField: "Cookie")
            urlRequest.addValue(username!, forHTTPHeaderField: "X-login")
            urlRequest.addValue(authentificationToken!, forHTTPHeaderField: "X-token")
            
            let sessionConfiguration = URLSessionConfiguration.default
            
            let urlSession = URLSession(configuration:sessionConfiguration, delegate: nil, delegateQueue: nil)
            urlSession.dataTask(with: urlRequest, completionHandler: { [weak self] (data, response, error) -> Void in
                if error == nil {
                    if let response = response, let statusCode = (response as? HTTPURLResponse)?.statusCode {
                        if statusCode == 200 {
                            
                            guard let dataResponse = data, error == nil else {
                                callback.onSitesLoaded(self?.sites, String("statusCode: \(statusCode)"))
                                return
                            }
                            do {
                                
                                let jsonResponse = try JSONSerialization.jsonObject(with: dataResponse, options: [])
                                
                                guard let jsonDictionary = jsonResponse as? [String: Any], let updatesArray = jsonDictionary["update"] as? [[String: Any]] else {
                                    callback.onSitesLoaded(self?.sites, String("statusCode: Error parsing data"))
                                    return
                                }
                                
                                for update in updatesArray {
                                    if let data = update["data"] as? [String: Any], let client = data["client"] as? [String: Any], let sit = client["site"] as? [String: Any],
                                        let commands = sit["commands"] as? [String: Any], let setSite = commands["setSite"] as? [String: Any],
                                        let params = setSite["params"] as? [String: Any], let site = params["site"] as? [String: Any],
                                        let options = site["options"] as? [[String: Any]] {
                                        
                                        self?.sites = [Site]()
                                        _ = options.map { if let siteName = $0["label"] as? String { self?.sites?.append(Site(siteName: siteName)) } }

                                    } else {
                                        callback.onSitesLoaded(self?.sites, String("statusCode: Error parsing data"))
                                        return
                                    }

                                }
                                
                            } catch let parsingError {
                                callback.onSitesLoaded(self?.sites, String("statusCode:\(String(describing: parsingError.localizedDescription))"))
                                return
                            }

                        }
                        callback.onSitesLoaded(self?.sites, String("statusCode: \(statusCode)"))
                    } else {
                        callback.onSitesLoaded(self?.sites, String("statusCode: \(-1)"))
                    }
                } else {
                    callback.onSitesLoaded(self?.sites, String("statusCode:\(String(describing: error?.localizedDescription))"))
                }
                
            }).resume()
        }
    }

}


//
//  NetworkStatusChecker.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 7/8/24.
//

import Foundation


public enum NetworkStatus:String {
    case unknown;
    case poor;
    case good;
    case notConnected
}

protocol NetworkStatusCheckerDelegate: AnyObject {
    func callWhileNetworkStatusChange(networkStatus: NetworkStatus)
}

class NetworkStatusChecker: NSObject {
    
    var testURL: URL?
    weak var delegate: NetworkStatusCheckerDelegate?
    private var startTime = CFAbsoluteTime()
    private var stopTime = CFAbsoluteTime()
    private var bytesReceived: CGFloat = 0
    var speedTestCompletionHandler: ((_ megabytesPerSecond: CGFloat, _ error: Error?) -> Void)? = nil    
    
    func startTest(url: URL){
        testURL = url
        self.testForSpeed()
    }

    func networkStatusChange(networkStatus: NetworkStatus) {
        self.delegate?.callWhileNetworkStatusChange(networkStatus: networkStatus)
    }
    
    @objc func testForSpeed()
    {
        testDownloadSpeed(withTimout: 2.0, completionHandler: {(_ megabytesPerSecond: CGFloat, _ error: Error?) -> Void in
            print("%0.1f; KbPerSec = \(megabytesPerSecond)")
            if (error as NSError?)?.code == -1009 {
                self.networkStatusChange(networkStatus: .notConnected)
                
            }
            else if megabytesPerSecond == -1.0 {
                self.networkStatusChange(networkStatus: .poor)
            }
            else {
                self.networkStatusChange(networkStatus: .good)
            }
        })
    }
}

extension NetworkStatusChecker: URLSessionDataDelegate, URLSessionDelegate {
    
    func testDownloadSpeed(withTimout timeout: TimeInterval, completionHandler: @escaping (_ megabytesPerSecond: CGFloat, _ error: Error?) -> Void) {
        
        // you set any relevant string with any file
        let urlForSpeedTest = testURL
        
        startTime = CFAbsoluteTimeGetCurrent()
        stopTime = startTime
        bytesReceived = 0
        speedTestCompletionHandler = completionHandler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        guard let checkedUrl = urlForSpeedTest else { return }
        
        session.dataTask(with: checkedUrl).resume()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        bytesReceived += CGFloat(data.count)
        stopTime = CFAbsoluteTimeGetCurrent()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let elapsed = (stopTime - startTime) //as? CFAbsoluteTime
        let speed: CGFloat = elapsed != 0 ? bytesReceived / (CGFloat(CFAbsoluteTimeGetCurrent() - startTime)) / 1024.0 : -1.0
        // treat timeout as no error (as we're testing speed, not worried about whether we got entire resource or not
        if error == nil || ((((error as NSError?)?.domain) == NSURLErrorDomain) && (error as NSError?)?.code == NSURLErrorTimedOut) {
            speedTestCompletionHandler?(speed, nil)
        }
        else {
            speedTestCompletionHandler?(speed, error)
        }
    }
}

//
//  SBUDownloadManager.swift
//  SendbirdUIKit
//
//  Created by Harry Kim on 2020/03/05.
//  Copyright © 2020 Sendbird, Inc. All rights reserved.
//

import UIKit
import Photos
import JuggleIM

class SBUDownloadManager {
    fileprivate static var imageView = UIImageView()

    // MARK: - SBUFileData
    /// Downloads the file inside the given fileData.
    /// - Parameters:
    ///     - fileData: The SBUFileData whose file is to be downloaded
    ///     - parent: The ViewController that is currently displaying the fileData.
    /// - Since: 3.10.0
    public static func save(fileData: SBUFileData, viewController: UIViewController) {
        switch fileData.fileType {
        case .image:
            Self.saveImage(fileData: fileData, viewController: viewController)
        default:
            Self.saveFile(fileData: fileData, viewController: viewController)
        }
    }
    
    static func saveImage(
        fileData: SBUFileData,
        viewController: UIViewController
    ) {
        DispatchQueue.global(qos: .background).async {
            let downloadHandler: ((URL) -> Void) = { fileURL in
                DispatchQueue.main.async {
                    SBULoading.stop()
                    
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetCreationRequest.forAsset().addResource(
                            with: .photo,
                            fileURL: fileURL,
                            options: nil
                        )
                    } completionHandler: { completed, error in
                        guard error == nil else {
                            SBULog.error("[Failed] Save image: \(String(describing: error))")
                            SBUToastView.show(type: .file(.downloadFailed))
                            return
                        }
                        
                        if completed {
                            SBULog.info("[Succeed] Image saved.")
                            SBUToastView.show(type: .file(.downloadSuccess))
                        }
                    }
                }
            }
            
            DispatchQueue.main.async { SBULoading.start() }
            
            let fileName = SBUCacheManager.Image.createCacheFileName(
                urlString: fileData.urlString,
                cacheKey: fileData.cacheKey,
                needPathExtension: true
            )
            
            let key = SBUCacheManager.Image.key(
                fileName: fileName,
                subPath: fileData.subPath
            )
            
            if SBUCacheManager.Image.diskCache.cacheExists(key: key) {
                let filePath = URL(fileURLWithPath: SBUCacheManager.Image.diskCache.pathForKey(key))
                downloadHandler(filePath)
            } else {
                DispatchQueue.main.async {
                    Self.imageView.image = nil
                    _ = Self.imageView.loadOriginalImage(
                        urlString: fileData.urlString,
                        errorImage: nil,
                        cacheKey: key,
                        subPath: fileData.subPath
                    ) { result in
                        if result.status.isSuccess {
                            let filePath = URL(fileURLWithPath: SBUCacheManager.Image.diskCache.pathForKey(fileName))
                            downloadHandler(filePath)
                        } else {
                            DispatchQueue.main.async { SBULoading.stop() }
                        }
                    }
                }
            }
        }
    }
    
    static func saveFile(
        fileData: SBUFileData,
        viewController: UIViewController
    ) {
        DispatchQueue.global(qos: .background).async {
            let downloadHandler: ((URL) -> Void) = { fileURL in
                DispatchQueue.main.async { [weak viewController] in
                    let activityVC = UIActivityViewController(
                        activityItems: [fileURL],
                        applicationActivities: nil
                    )
                    let transparentVC = UIViewController()
                    transparentVC.view.isOpaque = true
                    transparentVC.modalPresentationStyle = .overFullScreen
                    
                    activityVC.completionWithItemsHandler = { [weak viewController] _, completed, _, _ in
                        // For iOS 13 issue
                        transparentVC.dismiss(animated: true, completion: nil)
                        viewController?.presentedViewController?.dismiss(animated: true, completion: {
                            if completed {
                                SBULog.info("[Succeed] File is saved.")
                                SBUToastView.show(type: .file(.downloadSuccess))
                            }
                        })
                    }
                    
                    if #available(iOS 13.0, *) {
                        // For iOS 13 issue
                        viewController?.present(transparentVC, animated: true) { [weak transparentVC] in
                            transparentVC?.present(activityVC, animated: true)
                        }
                    } else {
                        viewController?.present(activityVC, animated: true)
                    }
                    
                    SBULoading.stop()
                }
            }
            
            DispatchQueue.main.async { SBULoading.start() }
            
            SBUCacheManager.File.loadFile(
                urlString: fileData.urlString,
                cacheKey: fileData.cacheKey,
                fileName: fileData.name
            ) { fileURL, _ in
                if let fileURL = fileURL {
                    downloadHandler(fileURL)
                } else {
                    DispatchQueue.main.async { SBULoading.stop() }
                }
            }
        }
    }
    
    // MARK: - File Message
    /// Downloads the file inside the given file message.
    /// - Parameters:
    ///     - fileMessage: The FileMessage whose file is to be downloaded
    ///     - parent: The ViewController that is currently displaying the file message.
    /// - Since: 3.10.0
    public static func save(message: JMessage, parent: UIViewController?) {
        switch message.content {
        case is JImageMessage:
            SBUDownloadManager.saveImage(with: message, parent: parent)
        default:
            SBUDownloadManager.saveFile(with: message, parent: parent)
        }
    }
    
    static func saveImage(with message: JMessage, parent: UIViewController?) {
        guard parent != nil else {
            SBULog.error("[Failed] Save image")
            return
        }
        guard let imageMessage = message.content as? JImageMessage, let url = imageMessage.url else {
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            let downloadHandler: ((URL) -> Void) = { fileURL in
                DispatchQueue.main.async {
                    SBULoading.stop()
                    
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetCreationRequest.forAsset().addResource(
                            with: .photo,
                            fileURL: fileURL,
                            options: nil
                        )
                    } completionHandler: { completed, error in
                        guard error == nil else {
                            SBULog.error("[Failed] Save image: \(String(describing: error))")
                            SBUToastView.show(type: .file(.downloadFailed))
                            return
                        }
                        
                        if completed {
                            SBULog.info("[Succeed] Image saved.")
                            SBUToastView.show(type: .file(.downloadSuccess))
                        }
                    }
                }
            }
            
            DispatchQueue.main.async { SBULoading.start() }
            
            let fileName = SBUCacheManager.Image.createCacheFileName(
                urlString: url,
                cacheKey: nil,
                needPathExtension: true
            )
            
            let fullPath = SBUCacheManager.Image.key(fileName: fileName, subPath: "")
            if SBUCacheManager.Image.diskCache.cacheExists(key: fullPath) {
                let filePath = URL(fileURLWithPath: SBUCacheManager.Image.diskCache.pathForKey(fullPath))
                downloadHandler(filePath)
            } else {
                DispatchQueue.main.async {
                    Self.imageView.image = nil
                    _ = Self.imageView.loadOriginalImage(
                        urlString: url,
                        errorImage: nil,
                        cacheKey: "",
                        subPath: ""
                    ) { result in
                        if result.status.isSuccess {
                            let filePath = URL(fileURLWithPath: SBUCacheManager.Image.diskCache.pathForKey(fullPath))
                            downloadHandler(filePath)
                        } else {
                            DispatchQueue.main.async { SBULoading.stop() }
                        }
                    }
                }
            }
        }
    }
    
    static func saveFile(with message: JMessage, parent: UIViewController?) {
        guard let parent = parent else {
            SBULog.error("[Failed] Save file")
            return
        }
        guard let fileMessage = message.content as? JFileMessage, let url = fileMessage.url else {
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            let downloadHandler: ((URL) -> Void) = { fileURL in
                DispatchQueue.main.async { [weak parent] in
                    let activityVC = UIActivityViewController(
                        activityItems: [fileURL],
                        applicationActivities: nil
                    )
                    let transparentVC = UIViewController()
                    transparentVC.view.isOpaque = true
                    transparentVC.modalPresentationStyle = .overFullScreen
                    
                    activityVC.completionWithItemsHandler = { [weak parent] _, completed, _, _ in
                        // For iOS 13 issue
                        transparentVC.dismiss(animated: true, completion: nil)
                        parent?.presentedViewController?.dismiss(animated: true, completion: {
                            if completed {
                                SBULog.info("[Succeed] File is saved.")
                                SBUToastView.show(type: .file(.downloadSuccess))
                            }
                        })
                    }
                    
                    if #available(iOS 13.0, *) {
                        // For iOS 13 issue
                        parent?.present(transparentVC, animated: true) { [weak transparentVC] in
                            transparentVC?.present(activityVC, animated: true)
                        }
                    } else {
                        parent?.present(activityVC, animated: true)
                    }
                    
                    SBULoading.stop()
                }
            }
            
            DispatchQueue.main.async { SBULoading.start() }
            
            SBUCacheManager.File.loadFile(
                urlString: url,
                cacheKey: "",
                fileName: fileMessage.name
            ) { fileURL, _ in
                if let fileURL = fileURL {
                    downloadHandler(fileURL)
                } else {
                    DispatchQueue.main.async { SBULoading.stop() }
                }
            }
        }
    }
}

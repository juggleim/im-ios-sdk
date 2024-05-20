//
//  Array+SBUIKit.swift
//  SendbirdUIKit
//
//  Created by Tez Park on 2020/07/16.
//  Copyright © 2020 Sendbird, Inc. All rights reserved.
//

import UIKit
import JetIM

public extension Array where Element: SBUUser {
    /// This is a function that extracts the userId array using the `SBUUser` type array.
    /// - Returns: userId `String` type array
    func sbu_getUserIds() -> [String] {
        let userIds: [String] = self.map({ $0.userId })
        return userIds
    }
    
    /// This is a function that extracts the nickname array using the `SBUUser` type array.
    /// - Returns: nickname `String` type array
    func sbu_getUserNicknames() -> [String] {
        let userNicknames: [String] = self.map({ $0.refinedNickname() })
        return userNicknames
    }
    
    /// This function updates the operator status of each user in the array based on the given channel.
    /// - Parameter channel: The channel where the operator status will be checked.
    /// - Returns: The array of users with updated operator status.
//    func sbu_updateOperatorStatus(channel: BaseChannel) -> [SBUUser] {
//        if let channel = channel as? OpenChannel {
//            for user in self {
//                let isOperator = channel.isOperator(userId: user.userId)
//                user.isOperator = isOperator
//            }
//        }
//        return self
//    }
    //TODO:
}

public extension Array where Element: JUserInfo {
    /// This is a function that extracts the `SBUUser` array using the `User` type array.
    /// - Returns: `SBUUser`  type array
    func sbu_convertUserList() -> [SBUUser] {
        let userList = self.map { SBUUser(user: $0) }
        return userList
    }
}

//public extension Array where Element: Member {
//    /// This is a function that extracts the `SBUUser` array using the `Member` type array.
//    /// - Returns: `SBUUser`  type array
//    func sbu_convertUserList() -> [SBUUser] {
//        let userList = self.map { SBUUser(member: $0) }
//        return userList
//    }
//}
//TODO:

extension Array where Element: JMessage {
    
    /// If only Stream messages exist, functions that return just that one message
    /// - Returns: optional Base Message
    /// - Since: 3.20.0
    public func hasStreamMessageOnly(with latestMessage: JMessage?) -> JMessage? {
        guard let latestMessage = latestMessage else { return nil }
        guard self.count == 1 else { return nil }
        guard let message = self.first else { return nil }
        guard message.messageId == latestMessage.messageId else { return nil }
        guard message.timestamp == 0 else { return  nil }
        guard message.messageState == .sent else { return nil }
        guard message.senderUserId != SBUGlobals.currentUser?.userId else { return nil }
        
        return message
    }
}

public extension NSArray {
    /// This is a function that extracts the userId array using the `SBUUser` type array.
    /// This is a function used in Objective-C.
    /// - Returns: userId `String` type array
    func sbu_getUserIds() -> [String] {
        guard let users = self as? [SBUUser] else { return [] }
        return users.sbu_getUserIds()
    }
    
    /// This is a function that extracts the nickname array using the `SBUUser` type array.
    /// This is a function used in Objective-C.
    /// - Returns: nickname `String` type array
    func sbu_getUserNicknames() -> [String] {
        guard let users = self as? [SBUUser] else { return [] }
        return users.sbu_getUserNicknames()
    }
    
    /// This is a function that extracts the `SBUUser` array using the `User` type array.
    /// This is a function used in Objective-C.
    /// - Returns: `SBUUser`  type array
    func sbu_convertUserList() -> [SBUUser] {
        guard let users = self as? [JUserInfo] else { return [] }
        return users.sbu_convertUserList()
    }
}

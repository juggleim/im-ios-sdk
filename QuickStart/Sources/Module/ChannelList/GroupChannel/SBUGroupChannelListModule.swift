//
//  SBUGroupChannelListComponent.swift
//  SendbirdUIKit
//
//  Created by Tez Park on 2021/09/01.
//  Copyright © 2021 Sendbird, Inc. All rights reserved.
//

import UIKit

// MARK: GroupChannelListModule

/// The class that represents the list of the group channel module
open class SBUGroupChannelListModule {
    // MARK: Properties (Public)
    /// The module component that contains ``SBUBaseChannelListModule/Header/titleView``, ``SBUBaseChannelListModule/Header/leftBarButton``, and ``SBUBaseChannelListModule/Header/rightBarButton``.
    /// - Since: 3.6.0
    public static var HeaderComponent: SBUGroupChannelListModule.Header.Type = SBUGroupChannelListModule.Header.self
    /// The module component that shows the list of message in the channel.
    /// - Since: 3.6.0
    public static var ListComponent: SBUGroupChannelListModule.List.Type = SBUGroupChannelListModule.List.self
    
    // MARK: [IMPORTANT] Will be deprecated
    
    /// The module component that contains ``SBUBaseChannelListModule/Header/titleView``, ``SBUBaseChannelListModule/Header/leftBarButton``, and ``SBUBaseChannelListModule/Header/rightBarButton``.
    /// - The default function of each button is as below:
    ///   - `title`: Shows the title that uses ``SBUStringSet/ChannelList_Header_Title`` in ``SBUStringSet``
    ///   - `leftBarButton`: Goes back to the previous view.
    ///   - `rightBarButton`: Shows a view controller creating a new group channel.
    @available(*, deprecated, message: "Use `SBUGroupChannelListModule.HeaderComponent` instead.")
    public var headerComponent: SBUGroupChannelListModule.Header? {
        get { _headerComponent ?? Self.HeaderComponent.init() }
        set {
            _headerComponent = newValue
            if let validNewValue = newValue {
                Self.HeaderComponent = type(of: validNewValue)
            }
        }
    }
    
    /// The module component that shows the list of message in the channel.
    @available(*, deprecated, message: "Use `SBUGroupChannelListModule.ListComponent` instead.")
    public var listComponent: SBUGroupChannelListModule.List? {
        get { _listComponent ?? Self.ListComponent.init() }
        set {
            _listComponent = newValue
            if let validNewValue = newValue {
                Self.ListComponent = type(of: validNewValue)
            }
        }
    }
    
    // MARK: Properties (Holder)
    private var _headerComponent: SBUGroupChannelListModule.Header?
    private var _listComponent: SBUGroupChannelListModule.List?
    
    // MARK: -
    /// Default initializer for `SBUGroupChannelListModule`.
    /// This initializer creates an instance of `SBUGroupChannelListModule` without any pre-configured components.
    public required init() {}
    
    /// This is deprecated and Use `SBUModuleSet.GroupChannelListModule` instead.
    @available(*, deprecated, message: "Use `SBUModuleSet.GroupChannelListModule`")
    public required init(
        headerComponent: SBUGroupChannelListModule.Header?
    ) {
        self._headerComponent = headerComponent
    }
    
    /// This is deprecated and Use `SBUModuleSet.GroupChannelListModule` instead.
    @available(*, deprecated, message: "Use `SBUModuleSet.GroupChannelListModule`")
    public required init(
        listComponent: SBUGroupChannelListModule.List?
    ) {
        self._listComponent = listComponent
    }
    
    /// This is deprecated and Use `SBUModuleSet.GroupChannelListModule` instead.
    @available(*, deprecated, message: "Use `SBUModuleSet.GroupChannelListModule`")
    public required init(
        headerComponent: SBUGroupChannelListModule.Header?,
        listComponent: SBUGroupChannelListModule.List?
    ) {
        self._headerComponent = headerComponent
        self._listComponent = listComponent
    }
}

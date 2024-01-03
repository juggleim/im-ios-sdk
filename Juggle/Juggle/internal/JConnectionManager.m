//
//  JConnectionManager.m
//  Juggle
//
//  Created by Nathan on 2023/11/29.
//

#import "JConnectionManager.h"
#import "JWebSocket.h"
#import "JHeartBeatManager.h"
#import "JNaviManager.h"
#import "JuggleConstInternal.h"

@interface JConnectionManager () <JWebSocketConnectDelegate>
@property (nonatomic, strong) JuggleCore *core;
@property (nonatomic, strong) JConversationManager *conversationManager;
@property (nonatomic, strong) JMessageManager *messageManager;
@property (nonatomic, strong) JHeartBeatManager *heartBeatManager;
@property (nonatomic, weak) id<JConnectionDelegate> delegate;
@property (nonatomic, strong) NSTimer *reconnectTimer;
@end

@implementation JConnectionManager

- (instancetype)initWithCore:(JuggleCore *)core
         conversationManager:(nonnull JConversationManager *)conversationManager
              messageManager:(nonnull JMessageManager *)messageManager {
    JConnectionManager *m = [[JConnectionManager alloc] init];
    [core.webSocket setConnectDelegate:m];
    core.connectionStatus = JConnectionStatusInternalIdle;
    m.core = core;
    m.conversationManager = conversationManager;
    m.messageManager = messageManager;
    JHeartBeatManager *heartBeatManager = [[JHeartBeatManager alloc] initWithCore:core];
    m.heartBeatManager = heartBeatManager;
    return m;
}

- (void)connectWithToken:(NSString *)token {
    //TODO: 连接状态判断，如果是连接中而且 token 跟之前的一样的话，直接 return
    
    if (![self.core.token isEqualToString:token]) {
        //token 更新了，则原来缓存的 userId 不再适用
        self.core.token = token;
        self.core.userId = @"";
    }
    if (self.core.userId.length > 0) {
        if ([self.core.dbManager openIMDB:self.core.appKey userId:self.core.userId]) {
            [self dbOpenNotice:JDBStatusOpen];
        }
    }
    [self changeStatus:JConnectionStatusInternalConnecting];
    
    [JNaviManager requestNavi:[NSURL URLWithString:self.core.naviUrl]
                       appKey:self.core.appKey
                        token:token
                      success:^(NSString * _Nonnull userId, NSArray<NSString *> * _Nonnull servers) {
        self.core.servers = servers;
        [self.core.webSocket connect:self.core.appKey token:token servers:self.core.servers];
    } failure:^(JErrorCodeInternal errorCode) {
        [self reconnect];
    }];
//    [self.core.webSocket connect:self.core.appKey token:token];
}

- (void)disconnect:(BOOL)receivePush {
    NSLog(@"[Juggle] disconnect, receivePush is %d", receivePush);
    [self changeStatus:JConnectionStatusInternalDisconnected];
    [self.core.webSocket disconnect:receivePush];
}

- (void)setDelegate:(id<JConnectionDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark - JWebSocketConnectDelegate
- (void)connectCompleteWithCode:(JErrorCodeInternal)error
                         userId:(NSString *)userId {
    if (error == JErrorCodeInternalNone) {
        self.core.userId = userId;
        if (self.core.dbStatus != JDBStatusOpen) {
            if ([self.core.dbManager openIMDB:self.core.appKey userId:userId]) {
                [self dbOpenNotice:JDBStatusOpen];
            } else {
                NSLog(@"[Juggle] db open fail");
            }
        }
        [self changeStatus:JConnectionStatusInternalConnected];
        //TODO: operation queue
        [self.conversationManager syncConversations:^{
            [self.messageManager syncMessages];
        }];
    } else {
        if ([self checkConnectionFailure:error]) {
            [self changeStatus:JConnectionStatusInternalFailure];
        } else {
            [self changeStatus:JConnectionStatusInternalWaitingForConnecting];
        }
    }
}

- (void)webSocketDidFail {
    [self changeStatus:JConnectionStatusInternalWaitingForConnecting];
}

- (void)webSocketDidClose {
    dispatch_async(self.core.sendQueue, ^{
        if (self.core.connectionStatus == JConnectionStatusInternalDisconnected
            || self.core.connectionStatus == JConnectionStatusInternalFailure) {
            return;
        }
        [self changeStatus:JConnectionStatusInternalWaitingForConnecting];
    });
}

#pragma mark -- internal
- (void)changeStatus:(JConnectionStatusInternal)status {
    dispatch_async(self.core.sendQueue, ^{
        if (status == JConnectionStatusInternalIdle) {
            self.core.connectionStatus = status;
            return;
        }
        if (status == JConnectionStatusInternalConnected && self.core.connectionStatus != JConnectionStatusInternalConnected) {
            [self.heartBeatManager start];
        }
        if (self.core.connectionStatus == JConnectionStatusInternalConnected && status != JConnectionStatusInternalConnected) {
            [self.heartBeatManager stop];
        }
        JConnectionStatus outStatus = JConnectionStatusIdle;
        switch (status) {
            case JConnectionStatusInternalConnected:
                outStatus = JConnectionStatusConnected;
                break;
                
            case JConnectionStatusInternalDisconnected:
                outStatus = JConnectionStatusConnected;
                break;
                
            case JConnectionStatusInternalConnecting:
                outStatus = JConnectionStatusConnecting;
                break;
                
            case JConnectionStatusInternalTokenIncorrect:
                outStatus = JConnectionStatusTokenIncorrect;
                break;
                
            case JConnectionStatusInternalWaitingForConnecting:
                [self reconnect];
                //已经在连接中，不需要再对外抛回调
                if (self.core.connectionStatus == JConnectionStatusInternalConnecting ||
                    self.core.connectionStatus == JConnectionStatusInternalWaitingForConnecting) {
                    self.core.connectionStatus = JConnectionStatusInternalWaitingForConnecting;
                    return;
                }
                outStatus = JConnectionStatusConnecting;
                break;
                
            case JConnectionStatusInternalFailure:
                outStatus = JConnectionStatusFailure;
                break;
                
            default:
                break;
        }
        self.core.connectionStatus = status;
        dispatch_async(self.core.delegateQueue, ^{
            if (self.delegate) {
                [self.delegate connectionStatusDidChange:outStatus errorCode:JErrorCodeNone];
            }
        });
    });
}

- (void)dbOpenNotice:(JDBStatus)status {
    dispatch_async(self.core.sendQueue, ^{
        self.core.dbStatus = status;
        if (status == JDBStatusOpen) {
            [self.core getSyncTimeFromDB];
        }
        dispatch_async(self.core.delegateQueue, ^{
            if (self.delegate) {
                if (status == JDBStatusOpen) {
                    [self.delegate dbDidOpen];
                } else {
                    [self.delegate dbDidClose];
                }
            }
        });
    });
}

- (void)reconnect {
    //需要在 sendQueue 里
    NSLog(@"[Juggle] reconnect");
    //TODO: 线程控制，间隔控制
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.reconnectTimer) {
            return;
        }
        self.reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                               target:self
                                                             selector:@selector(reconnectTimerFired)
                                                             userInfo:nil
                                                              repeats:NO];
    });
}

- (void)reconnectTimerFired {
    if (self.reconnectTimer) {
        [self.reconnectTimer invalidate];
    }
    self.reconnectTimer = nil;
    [self connectWithToken:self.core.token];
}

- (BOOL)checkConnectionFailure:(JErrorCodeInternal)code {
    if (code == JErrorCodeInternalAppKeyEmpty ||
        code == JErrorCodeInternalTokenEmpty ||
        code == JErrorCodeInternalAppKeyInvalid ||
        code == JErrorCodeInternalTokenIllegal ||
        code == JErrorCodeInternalTokenUnauthorized ||
        code == JErrorCodeInternalTokenExpired ||
        code == JErrorCodeInternalAppProhibited ||
        code == JErrorCodeInternalUserProhibited ||
        code == JErrorCodeInternalUserKickedByOtherClient ||
        code == JErrorCodeInternalUserLogOut
        ) {
        return YES;
    }
    return NO;
}

@end

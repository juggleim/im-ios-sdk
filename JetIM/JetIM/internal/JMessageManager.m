//
//  JMessageManager.m
//  JetIM
//
//  Created by Nathan on 2023/11/29.
//

#import "JMessageManager.h"
#import "JetIMConst.h"
#import "JTextMessage.h"
#import "JImageMessage.h"
#import "JFileMessage.h"
#import "JVoiceMessage.h"
#import "JContentTypeCenter.h"
#import "JRecallInfoMessage.h"
#import "JRecallCmdMessage.h"
#import "JDeleteConvMessage.h"
#import "JReadNtfMessage.h"
#import "JGroupReadNtfMessage.h"

@interface JMessageManager () <JWebSocketMessageDelegate>
@property (nonatomic, strong) JetIMCore *core;
@property (nonatomic, weak) id<JMessageDelegate> delegate;
@property (nonatomic, weak) id<JMessageSyncDelegate> syncDelegate;
@property (nonatomic, weak) id<JMessageReadReceiptDelegate> readReceiptDelegate;
@property (nonatomic, assign) int increaseId;
//在 receiveQueue 里处理
@property (nonatomic, assign) BOOL syncProcessing;
@property (nonatomic, assign) long long cachedReceiveTime;
@property (nonatomic, assign) long long cachedSendTime;
@end

@implementation JMessageManager

- (void)syncMessages {
    self.syncProcessing = YES;
    [self sync];
}

- (instancetype)initWithCore:(JetIMCore *)core {
    if (self = [super init]) {
        self.core = core;
        [self.core.webSocket setMessageDelegate:self];
        [self registerContentType:[JTextMessage class]];
        [self registerContentType:[JImageMessage class]];
        [self registerContentType:[JFileMessage class]];
        [self registerContentType:[JVoiceMessage class]];
        [self registerContentType:[JVideoMessage class]];
        [self registerContentType:[JRecallCmdMessage class]];
        [self registerContentType:[JRecallInfoMessage class]];
        [self registerContentType:[JDeleteConvMessage class]];
        [self registerContentType:[JReadNtfMessage class]];
        [self registerContentType:[JGroupReadNtfMessage class]];
        [self registerContentType:[JMergeMessage class]];
        self.cachedSendTime = -1;
        self.cachedReceiveTime = -1;
    }
    return self;
}

- (void)setDelegate:(id<JMessageDelegate>)delegate {
    _delegate = delegate;
}

- (void)setSyncDelegate:(id<JMessageSyncDelegate>)syncDelegate {
    _syncDelegate = syncDelegate;
}

- (void)setReadReceiptDelegate:(id<JMessageReadReceiptDelegate>)delegate {
    _readReceiptDelegate = delegate;
}

- (void)deleteMessageByClientMsgNo:(long long)clientMsgNo {
    [self.core.dbManager deleteMessageByClientId:clientMsgNo];
}

- (void)deleteMessageByMessageId:(NSString *)messageId {
    [self.core.dbManager deleteMessageByMessageId:messageId];
}

- (void)recallMessage:(NSString *)messageId
              success:(void (^)(JMessage *))successBlock
                error:(void (^)(JErrorCode))errorBlock {
    NSArray *arr = [self getMessagesByMessageIds:@[messageId]];
    if (arr.count > 0) {
        JMessage *m = arr[0];
        if ([m.contentType isEqualToString:[JRecallInfoMessage contentType]]) {
            dispatch_async(self.core.delegateQueue, ^{
                if (errorBlock) {
                    errorBlock(JErrorCodeMessageAlreadyRecalled);
                }
            });
            return;
        }
        [self.core.webSocket recallMessage:messageId
                              conversation:m.conversation
                                 timestamp:m.timestamp
                                   success:^(long long timestamp) {
            if (self.syncProcessing) {
                self.cachedSendTime = timestamp;
            } else {
                self.core.messageSendSyncTime = timestamp;
            }
            m.contentType = [JRecallInfoMessage contentType];
            JRecallInfoMessage *recallInfoMsg = [[JRecallInfoMessage alloc] init];
            m.content = recallInfoMsg;
            [self.core.dbManager updateMessageContent:recallInfoMsg
                                          contentType:m.contentType
                                        withMessageId:messageId];
            dispatch_async(self.core.delegateQueue, ^{
                if (successBlock) {
                    successBlock(m);
                }
            });
        } error:^(JErrorCodeInternal errorCode) {
            dispatch_async(self.core.delegateQueue, ^{
                if (errorBlock) {
                    errorBlock((JErrorCode)errorCode);
                }
            });
        }];
    } else {
        dispatch_async(self.core.delegateQueue, ^{
            if (errorBlock) {
                errorBlock(JErrorCodeMessageNotExist);
            }
        });
    }
}

- (void)clearMessagesIn:(JConversation *)conversation {
    [self.core.dbManager clearMessagesIn:conversation];
}

- (NSArray<JMessage *> *)getMessagesFrom:(JConversation *)conversation
                                   count:(int)count
                                    time:(long long)time
                               direction:(JPullDirection)direction {
    NSArray *arr = [[NSArray alloc] init];
    return [self getMessagesFrom:conversation
                           count:count
                            time:time
                       direction:direction
                    contentTypes:arr];
}

- (NSArray<JMessage *> *)getMessagesFrom:(JConversation *)conversation
                                   count:(int)count
                                    time:(long long)time
                               direction:(JPullDirection)direction
                            contentTypes:(NSArray<NSString *> *)contentTypes {
    return [self.core.dbManager getMessagesFrom:conversation
                                          count:count
                                           time:time
                                      direction:direction
                                   contentTypes:contentTypes];
}

- (JMessage *)saveMessage:(JMessageContent *)content
           inConversation:(JConversation *)conversation {
    JConcreteMessage *message = [[JConcreteMessage alloc] init];
    message.content = content;
    message.conversation = conversation;
    message.contentType = [[content class] contentType];
    message.direction = JMessageDirectionSend;
    message.messageState = JMessageStateUnknown;
    message.senderUserId = self.core.userId;
    message.clientUid = [self createClientUid];
    message.timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    [self.core.dbManager insertMessages:@[message]];
    if ([self.sendReceiveDelegate respondsToSelector:@selector(messageDidSave:)]) {
        [self.sendReceiveDelegate messageDidSave:message];
    }
    return message;
}

- (void)setMessageState:(JMessageState)state
        withClientMsgNo:(long long)clientMsgNo {
    [self.core.dbManager setMessageState:state
                         withClientMsgNo:clientMsgNo];
}

- (JMessage *)sendMessage:(JMessageContent *)content
           inConversation:(JConversation *)conversation
                  success:(void (^)(JMessage *))successBlock
                    error:(void (^)(JErrorCode, JMessage *))errorBlock {
    NSArray *mergedMessages = nil;
    if ([content isKindOfClass:[JMergeMessage class]]) {
        JMergeMessage *merge = (JMergeMessage *)content;
        mergedMessages = [self.core.dbManager getMessagesByMessageIds:merge.messageIdList];
    }
    return [self sendMessage:content
              inConversation:conversation
                  mergedMsgs:mergedMessages
                     success:successBlock
                       error:errorBlock];
}

- (void)sendReadReceipt:(NSArray<NSString *> *)messageIds
         inConversation:(JConversation *)conversation
                success:(void (^)(void))successBlock
                  error:(void (^)(JErrorCode))errorBlock {
    [self.core.webSocket sendReadReceipt:messageIds
                          inConversation:conversation
                                 success:^{
        [self.core.dbManager setMessagesRead:messageIds];
        dispatch_async(self.core.delegateQueue, ^{
            if (successBlock) {
                successBlock();
            }
        });
    } error:^(JErrorCodeInternal code) {
        dispatch_async(self.core.delegateQueue, ^{
            if (errorBlock) {
                errorBlock((JErrorCode)code);
            }
        });
    }];
}

- (void)getGroupMessageReadDetail:(NSString *)messageId
                   inConversation:(JConversation *)conversation
                          success:(void (^)(NSArray<JUserInfo *> *, NSArray<JUserInfo *> *))successBlock
                            error:(void (^)(JErrorCode))errorBlock {
    [self.core.webSocket getGroupMessageReadDetail:messageId
                                    inConversation:conversation
                                           success:^(NSArray<JUserInfo *> * _Nonnull readMembers, NSArray<JUserInfo *> * _Nonnull unreadMembers) {
        JGroupMessageReadInfo *info = [[JGroupMessageReadInfo alloc] init];
        info.readCount = (int)readMembers.count;
        info.memberCount = (int)readMembers.count + (int)unreadMembers.count;
        [self.core.dbManager setGroupMessageReadInfo:@{messageId:info}];
        dispatch_async(self.core.delegateQueue, ^{
            if (successBlock) {
                successBlock(readMembers, unreadMembers);
            }
        });
    } error:^(JErrorCodeInternal code) {
        dispatch_async(self.core.delegateQueue, ^{
            if (errorBlock) {
                errorBlock((JErrorCode)code);
            }
        });
    }];
}

- (JMessage *)resend:(JMessage *)messsage
             success:(void (^)(JMessage *))successBlock
               error:(void (^)(JErrorCode, JMessage *))errorBlock {
    if (messsage.clientMsgNo <= 0
        || !messsage.content
        || messsage.conversation.conversationId.length == 0) {
        dispatch_async(self.core.delegateQueue, ^{
            if (errorBlock) {
                errorBlock(JErrorCodeInvalidParam, messsage);
            }
        });
        return messsage;
    }
    [self deleteMessageByClientMsgNo:messsage.clientMsgNo];
    return [self sendMessage:messsage.content
              inConversation:messsage.conversation
                     success:successBlock
                       error:errorBlock];
}

- (void)getRemoteMessagesFrom:(JConversation *)conversation
                    startTime:(long long)startTime
                        count:(int)count
                    direction:(JPullDirection)direction
                      success:(void (^)(NSArray *messages))successBlock
                        error:(void (^)(JErrorCode code))errorBlock {
    if (count > 100) {
        count = 100;
    }
    [self.core.webSocket queryHisMsgsFrom:conversation
                                startTime:startTime
                                    count:count
                                direction:direction
                                  success:^(NSArray * _Nonnull messages, BOOL isFinished) {
        [self.core.dbManager insertMessages:messages];
        dispatch_async(self.core.delegateQueue, ^{
            if (successBlock) {
                successBlock(messages);
            }
        });
    } error:^(JErrorCodeInternal code) {
        dispatch_async(self.core.delegateQueue, ^{
            if (errorBlock) {
                errorBlock((JErrorCode)code);
            }
        });
    }];
}

- (void)getLocalAndRemoteMessagesFrom:(JConversation *)conversation
                            startTime:(long long)startTime
                                count:(int)count
                            direction:(JPullDirection)direction
                              success:(void (^)(NSArray *))successBlock
                                error:(void (^)(JErrorCode))errorBlock {
    if (count <= 0) {
        dispatch_async(self.core.delegateQueue, ^{
            if (successBlock) {
                NSArray *arr = [NSArray array];
                successBlock(arr);
            }
        });
        return;
    }
    if (count > 100) {
        count = 100;
    }
    NSArray *localMessages = [self getMessagesFrom:conversation
                                             count:count
                                              time:startTime
                                         direction:direction];
    __block BOOL needRemote = NO;
    if (localMessages.count > 0) {
        JConcreteMessage *message = localMessages[0];
        __block long long seqNo = message.seqNo;
        [localMessages enumerateObjectsUsingBlock:^(JConcreteMessage *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx > 0) {
                if (obj.seqNo > ++seqNo) {
                    needRemote = YES;
                    *stop = YES;
                    return;
                }
            }
        }];
    } else {
        needRemote = YES;
    }
    if (needRemote) {
        [self getRemoteMessagesFrom:conversation
                          startTime:startTime
                              count:count
                          direction:direction
                            success:successBlock
                              error:errorBlock];
    } else {
        dispatch_async(self.core.delegateQueue, ^{
            if (successBlock) {
                successBlock(localMessages);
            }
        });
    }
}

- (NSArray<JMessage *> *)getMessagesByMessageIds:(NSArray<NSString *> *)messageIds {
    return [self.core.dbManager getMessagesByMessageIds:messageIds];
}

- (void)getMessagesByMessageIds:(NSArray<NSString *> *)messageIds
                 inConversation:(JConversation *)conversation
                        success:(void (^)(NSArray<JMessage *> *))successBlock
                          error:(void (^)(JErrorCode))errorBlock {
    if (messageIds.count == 0) {
        dispatch_async(self.core.delegateQueue, ^{
            if (errorBlock) {
                errorBlock(JErrorCodeInvalidParam);
            }
        });
        return;
    }
    NSArray <JMessage *> *localMessages = [self.core.dbManager getMessagesByMessageIds:messageIds];
    NSMutableArray *notExistArray = [[NSMutableArray alloc] init];
    if (localMessages.count == 0) {
        notExistArray = [messageIds mutableCopy];
    } else if (localMessages.count < messageIds.count) {
        int localMessageIndex = 0;
        for (int i = 0; i < messageIds.count; i++) {
            if (localMessageIndex == localMessages.count) {
                [notExistArray addObject:messageIds[i]];
                continue;
            }
            if ([messageIds[i] isEqualToString:localMessages[localMessageIndex].messageId]) {
                localMessageIndex++;
            } else {
                [notExistArray addObject:messageIds[i]];
            }
        }
    }
    if (notExistArray.count > 0) {
        [self.core.webSocket queryHisMsgsByIds:notExistArray
                                inConversation:conversation
                                       success:^(NSArray<JConcreteMessage *> * _Nonnull remoteMessages, BOOL isFinished) {
            NSMutableArray <JMessage *> *result = [[NSMutableArray alloc] init];
            for (NSString *messageId in messageIds) {
                BOOL isMatch = NO;
                for (JMessage *localMessage in localMessages) {
                    if ([messageId isEqualToString:localMessage.messageId]) {
                        [result addObject:localMessage];
                        isMatch = YES;
                        break;
                    }
                }
                if (isMatch) {
                    continue;
                }
                for (JMessage *remoteMessage in remoteMessages) {
                    if ([messageId isEqualToString:remoteMessage.messageId]) {
                        [result addObject:remoteMessage];
                        break;
                    }
                }
            }
            dispatch_async(self.core.delegateQueue, ^{
                if (successBlock) {
                    successBlock(result);
                }
            });
        } error:^(JErrorCodeInternal code) {
            if (localMessages.count > 0) {
                dispatch_async(self.core.delegateQueue, ^{
                    if (successBlock) {
                        successBlock(localMessages);
                    }
                });
            } else if (errorBlock) {
                dispatch_async(self.core.delegateQueue, ^{
                    errorBlock((JErrorCode)code);
                });
            }
        }];
    } else {
        dispatch_async(self.core.delegateQueue, ^{
            if (successBlock) {
                successBlock(localMessages);
            }
        });
    }
}

- (void)getMergedMessageList:(NSString *)messageId
                     success:(void (^)(NSArray<JMessage *> *))successBlock
                       error:(void (^)(JErrorCode))errorBlock {
    [self.core.webSocket getMergedMessageList:messageId
                                         time:0
                                        count:100
                                    direction:JPullDirectionOlder
                                      success:^(NSArray<JConcreteMessage *> * _Nonnull messages, BOOL isFinished) {
        dispatch_async(self.core.delegateQueue, ^{
            if (successBlock) {
                successBlock(messages);
            }
        });
    } error:^(JErrorCodeInternal code) {
        dispatch_async(self.core.delegateQueue, ^{
            if (errorBlock) {
                errorBlock((JErrorCode)code);
            }
        });
    }];
}

- (NSArray<JMessage *> *)getMessagesByClientMsgNos:(NSArray<NSNumber *> *)clientMsgNos {
    return [self.core.dbManager getMessagesByClientMsgNos:clientMsgNos];
}

- (void)registerContentType:(Class)messageClass {
    [[JContentTypeCenter shared] registerContentType:messageClass];
}

#pragma mark - JWebSocketMessageDelegate
- (void)messageDidReceive:(JConcreteMessage *)message {
    [self handleReceiveMessages:@[message]
                         isSync:NO];
}

- (void)messagesDidReceive:(NSArray<JConcreteMessage *> *)messages
                isFinished:(BOOL)isFinished {
    [self handleReceiveMessages:messages
                         isSync:YES];
    
    if (!isFinished) {
        [self sync];
    } else {
        self.syncProcessing = NO;
        if (self.cachedSendTime > 0) {
            self.core.messageSendSyncTime = self.cachedSendTime;
            self.cachedSendTime = -1;
        }
        if (self.cachedReceiveTime > 0) {
            self.core.messageReceiveSyncTime = self.cachedReceiveTime;
            self.cachedReceiveTime = -1;
        }
        
        dispatch_async(self.core.delegateQueue, ^{
            if ([self.syncDelegate respondsToSelector:@selector(messageSyncDidComplete)]) {
                [self.syncDelegate messageSyncDidComplete];
            }
        });
    }
}

- (void)syncNotify:(long long)syncTime {
    NSLog(@"[JetIM] syncNotify syncTime is %lld, receiveSyncTime is %lld", syncTime, self.core.messageReceiveSyncTime);
    if (syncTime > self.core.messageReceiveSyncTime) {
        self.syncProcessing = YES;
        [self sync];
    }
}

#pragma mark - internal
- (JMessage *)sendMessage:(JMessageContent *)content
           inConversation:(JConversation *)conversation
               mergedMsgs:(NSArray <JConcreteMessage *> *)mergedMsgs
                  success:(void (^)(JMessage *))successBlock
                    error:(void (^)(JErrorCode, JMessage *))errorBlock{
   JConcreteMessage *message = [[JConcreteMessage alloc] init];
   message.content = content;
   message.conversation = conversation;
   message.contentType = [[content class] contentType];
   message.direction = JMessageDirectionSend;
   message.messageState = JMessageStateSending;
   message.senderUserId = self.core.userId;
   message.clientUid = [self createClientUid];
   message.timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
   [self.core.dbManager insertMessages:@[message]];
   
   if ([self.sendReceiveDelegate respondsToSelector:@selector(messageDidSave:)]) {
       [self.sendReceiveDelegate messageDidSave:message];
   }
   
   [self.core.webSocket sendIMMessage:content
                       inConversation:conversation
                          clientMsgNo:message.clientMsgNo
                            clientUid:message.clientUid
                           mergedMsgs:mergedMsgs
                               userId:self.core.userId
                              success:^(long long clientMsgNo, NSString *msgId, long long timestamp, long long seqNo) {
       if (self.syncProcessing) {
           self.cachedSendTime = timestamp;
       } else {
           self.core.messageSendSyncTime = timestamp;
       }
       [self.core.dbManager updateMessageAfterSend:message.clientMsgNo
                                         messageId:msgId
                                         timestamp:timestamp
                                             seqNo:seqNo];
       message.messageId = msgId;
       message.timestamp = timestamp;
       message.seqNo = seqNo;
       message.messageState = JMessageStateSent;
       
       if ([self.sendReceiveDelegate respondsToSelector:@selector(messageDidSend:)]) {
           [self.sendReceiveDelegate messageDidSend:message];
       }
       
       dispatch_async(self.core.delegateQueue, ^{
           if (successBlock) {
               successBlock(message);
           }
       });
   } error:^(JErrorCodeInternal errorCode, long long clientMsgNo) {
       message.messageState = JMessageStateFail;
       [self.core.dbManager messageSendFail:clientMsgNo];
       dispatch_async(self.core.delegateQueue, ^{
           if (errorBlock) {
               errorBlock((JErrorCode)errorCode, message);
           }
       });
   }];
   return message;
}


- (NSArray <JConcreteMessage *> *)messagesToSave:(NSArray <JConcreteMessage *> *)messages {
    NSMutableArray <JConcreteMessage *> *arr = [[NSMutableArray alloc] init];
    for (JConcreteMessage *message in messages) {
        if (message.flags & JMessageFlagIsSave) {
            [arr addObject:message];
        }
    }
    return arr;
}

- (JMessage *)handleRecallCmdMessage:(NSString *)messageId {
    JRecallInfoMessage *recallInfoMsg = [[JRecallInfoMessage alloc] init];
    [self.core.dbManager updateMessageContent:recallInfoMsg
                                  contentType:[JRecallInfoMessage contentType]
                                withMessageId:messageId];
    NSArray <JMessage *> *messages = [self.core.dbManager getMessagesByMessageIds:@[messageId]];
    if (messages.count > 0) {
        return messages[0];
    }
    return nil;
}

- (void)handleReceiveMessages:(NSArray<JConcreteMessage *> *)messages
                       isSync:(BOOL)isSync {
    NSArray <JConcreteMessage *> *messagesToSave = [self messagesToSave:messages];
    [self.core.dbManager insertMessages:messagesToSave];
    [self updateUserInfos:messagesToSave];
    //TODO: 遍历 messagesToSave，同一个会话的最后一个 message 更新会话的 lastMessage
    
    __block long long sendTime = 0;
    __block long long receiveTime = 0;
    [messages enumerateObjectsUsingBlock:^(JConcreteMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.direction == JMessageDirectionSend) {
            sendTime = obj.timestamp;
        } else if (obj.direction == JMessageDirectionReceive) {
            receiveTime = obj.timestamp;
        }
        
        //recall message
        if ([obj.contentType isEqualToString:[JRecallCmdMessage contentType]]) {
            JRecallCmdMessage *cmd = (JRecallCmdMessage *)obj.content;
            JMessage *recallMessage = [self handleRecallCmdMessage:cmd.originalMessageId];
            //recallMessage 为空表示被撤回的消息本地不存在，不需要回调
            if (recallMessage) {
                dispatch_async(self.core.delegateQueue, ^{
                    if ([self.delegate respondsToSelector:@selector(messageDidRecall:)]) {
                        [self.delegate messageDidRecall:recallMessage];
                    }
                });
            }
            return;
        }
        //delete conversation
        if ([obj.contentType isEqualToString:[JDeleteConvMessage contentType]]) {
            JDeleteConvMessage *deleteConvMsg = (JDeleteConvMessage *)obj.content;
            for (JConversation *deleteConversation in deleteConvMsg.conversations) {
                [self.core.dbManager deleteConversationInfoBy:deleteConversation];
            }
            if ([self.sendReceiveDelegate respondsToSelector:@selector(conversationsDidDelete:)]) {
                [self.sendReceiveDelegate conversationsDidDelete:deleteConvMsg.conversations];
            }
            return;
        }
        
        //read ntf
        if ([obj.contentType isEqualToString:[JReadNtfMessage contentType]]) {
            JReadNtfMessage *readNtfMsg = (JReadNtfMessage *)obj.content;
            [self.core.dbManager setMessagesRead:readNtfMsg.messageIds];
            dispatch_async(self.core.delegateQueue, ^{
                if ([self.readReceiptDelegate respondsToSelector:@selector(messagesDidRead:inConversation:)]) {
                    [self.readReceiptDelegate messagesDidRead:readNtfMsg.messageIds
                                               inConversation:obj.conversation];
                }
            });
            return;
        }
        
        //group read ntf
        if ([obj.contentType isEqualToString:[JGroupReadNtfMessage contentType]]) {
            JGroupReadNtfMessage *groupReadNtfMsg = (JGroupReadNtfMessage *)obj.content;
            [self.core.dbManager setGroupMessageReadInfo:groupReadNtfMsg.msgs];
            dispatch_async(self.core.delegateQueue, ^{
                if ([self.readReceiptDelegate respondsToSelector:@selector(groupMessagesDidRead:inConversation:)]) {
                    [self.readReceiptDelegate groupMessagesDidRead:groupReadNtfMsg.msgs
                                                    inConversation:obj.conversation];
                }
            });
            return;
        }
        
        if (obj.flags & JMessageFlagIsCmd) {
            return;
        }
        if (obj.existed) {
            return;
        }
        
        if ([self.sendReceiveDelegate respondsToSelector:@selector(messageDidReceive:)]) {
            [self.sendReceiveDelegate messageDidReceive:obj];
        }
        
        dispatch_async(self.core.delegateQueue, ^{
            if ([self.delegate respondsToSelector:@selector(messageDidReceive:)]) {
                [self.delegate messageDidReceive:obj];
            }
        });
    }];
    //直发的消息，而且正在同步中，不直接更新 sync time
    if (!isSync && self.syncProcessing) {
        if (sendTime > 0) {
            self.cachedSendTime = sendTime;
        }
        if (receiveTime > 0) {
            self.cachedReceiveTime = receiveTime;
        }
    } else {
        if (sendTime > 0) {
            self.core.messageSendSyncTime = sendTime;
        }
        if (receiveTime > 0) {
            self.core.messageReceiveSyncTime = receiveTime;
        }
    }
}

- (void)sync {
    [self.core.webSocket syncMessagesWithReceiveTime:self.core.messageReceiveSyncTime
                                            sendTime:self.core.messageSendSyncTime
                                              userId:self.core.userId];
}

- (NSString *)createClientUid {
    long long ts = [[NSDate date] timeIntervalSince1970];
    ts = ts % 1000000;
    return [NSString stringWithFormat:@"%06lld%03d", ts, self.increaseId++];
}

- (void)updateUserInfos:(NSArray <JConcreteMessage *> *)messages {
    NSMutableDictionary *groupDic = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *userDic = [[NSMutableDictionary alloc] init];
    [messages enumerateObjectsUsingBlock:^(JConcreteMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.groupInfo.groupId.length > 0) {
            [groupDic setObject:obj.groupInfo forKey:obj.groupInfo.groupId];
        }
        if (obj.targetUserInfo.userId.length > 0) {
            [userDic setObject:obj.targetUserInfo forKey:obj.targetUserInfo.userId];
        }
    }];
    [self.core.dbManager insertUserInfos:userDic.allValues];
    [self.core.dbManager insertGroupInfos:groupDic.allValues];
}

@end

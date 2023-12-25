//
//  JConcreteConversationInfo.h
//  Juggle
//
//  Created by Nathan on 2023/12/25.
//

#import <Juggle/Juggle.h>

NS_ASSUME_NONNULL_BEGIN

@interface JConcreteConversationInfo : JConversationInfo
@property (nonatomic, assign) long long lastReadMessageIndex;
@end

NS_ASSUME_NONNULL_END

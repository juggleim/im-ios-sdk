//
//  JGroupReadNtfMessage.h
// JuggleIM
//
//  Created by Nathan on 2024/3/6.
//

#import <JuggleIM/JuggleIM.h>
#import <JGroupMessageReadInfo.h>

NS_ASSUME_NONNULL_BEGIN

@interface JGroupReadNtfMessage : JMessageContent
@property (nonatomic, strong) NSDictionary <NSString *, JGroupMessageReadInfo *> *msgs;
@end

NS_ASSUME_NONNULL_END

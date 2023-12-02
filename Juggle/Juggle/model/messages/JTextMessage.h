//
//  JTextMessage.h
//  Juggle
//
//  Created by Nathan on 2023/12/2.
//

#import <Juggle/Juggle.h>

NS_ASSUME_NONNULL_BEGIN

@interface JTextMessage : JMessageContent

/*!
 文本消息的内容
 */
@property (nonatomic, copy) NSString *content;

@end

NS_ASSUME_NONNULL_END

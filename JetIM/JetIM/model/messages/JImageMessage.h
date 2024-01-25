//
//  JImageMessage.h
//  JetIM
//
//  Created by Nathan on 2023/12/3.
//

#import <JetIM/JetIM.h>

NS_ASSUME_NONNULL_BEGIN

@interface JImageMessage : JMessageContent
/// 图片的远端地址
@property (nonatomic, copy) NSString *url;
/// 缩略图的远端地址
@property (nonatomic, copy) NSString *thumbnailUrl;
/// 图片高度
@property (nonatomic, assign) int height;
/// 图片宽度
@property (nonatomic, assign) int width;
/// 扩展字段
@property (nonatomic, copy) NSString *extra;
@end

NS_ASSUME_NONNULL_END

//
//  JImageMessage.h
// JuggleIM
//
//  Created by Nathan on 2023/12/3.
//

#import <JuggleIM/JuggleIM.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface JImageMessage : JMediaMessageContent

- (instancetype)initWithImage:(UIImage *)image;

- (instancetype)initWithImage:(UIImage *)image
                     fileName:(NSString *)fileName;

///缩略图本地路径
@property (nonatomic, copy) NSString *thumbnailLocalPath;
/// 缩略图的远端地址
@property (nonatomic, copy) NSString *thumbnailUrl;
/// 图片高度
@property (nonatomic, assign) int height;
/// 图片宽度
@property (nonatomic, assign) int width;
/// 图片大小，单位：KB
@property (nonatomic, assign) long long size;
/// 扩展字段
@property (nonatomic, copy) NSString *extra;
@end

NS_ASSUME_NONNULL_END

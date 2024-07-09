//
//  JImageMessage.m
//  JetIM
//
//  Created by Nathan on 2023/12/3.
//

#import "JImageMessage.h"

#define kImageType @"jg:img"
#define kDigest @"[Image]"
#define jLocalPath @"local"
#define jURL @"url"
#define jThumbnail @"thumbnail"
#define jImageHeight @"height"
#define jImageWidth @"width"
#define jImageSize @"size"
#define jImageExtra @"extra"

@implementation JImageMessage

+ (NSString *)contentType {
    return kImageType;
}


- (NSData *)encode{
    NSDictionary * dic = @{jURL:self.url?:@"",
                           jThumbnail:self.thumbnailUrl?:@"",
                           jLocalPath:self.localPath?:@"",
                           jImageWidth:@(self.width),
                           jImageHeight:@(self.height),
                           jImageSize:@(self.size),
                           jImageExtra:self.extra?:@""};
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:kNilOptions error:nil];
    return data;
}

- (void)decode:(NSData *)data{
    NSDictionary * json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
    self.localPath = json[jLocalPath]?:@"";
    self.url = json[jURL]?:@"";
    self.thumbnailUrl = json[jThumbnail]?:@"";
    id obj = json[jImageWidth];
    if ([obj isKindOfClass:[NSNumber class]]) {
        self.width = [(NSNumber *)obj intValue];
    }
    obj = json[jImageHeight];
    if ([obj isKindOfClass:[NSNumber class]]) {
        self.height = [(NSNumber *)obj intValue];
    }
    obj = json[jImageSize];
    if ([obj isKindOfClass:[NSNumber class]]) {
        self.size = [(NSNumber *)obj longLongValue];
    }
    self.extra = json[jImageExtra]?:@"";
}

- (NSString *)conversationDigest {
    return kDigest;
}

@end

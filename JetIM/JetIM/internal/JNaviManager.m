//
//  JNaviManager.m
//  JetIM
//
//  Created by Nathan on 2023/12/29.
//

#import "JNaviManager.h"

#define jNaviServerSuffix @"/navigator/general"
#define jNaviAppKey @"x-appkey"
#define jNaviToken @"x-token"
#define jNaviData @"data"
#define jNaviUserId @"user_id"
#define jNaviServers @"servers"

@implementation JNaviManager

+ (void)requestNavi:(NSString *)url
             appKey:(NSString *)appKey
              token:(NSString *)token
            success:(void (^)(NSString *userId, NSArray<NSString *> *servers))success
            failure:(void (^)(JErrorCodeInternal))failure {
    NSURL *u = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", url, jNaviServerSuffix]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:u];
    [request setHTTPMethod:@"GET"];
    [request setValue:appKey forHTTPHeaderField:jNaviAppKey];
    [request setValue:token forHTTPHeaderField:jNaviToken];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[JetIM] request navi error, description is %@", error.localizedDescription);
            if (failure) {
                failure(JErrorCodeInternalNaviFailure);
            }
            return;
        }
        NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
        if (statusCode != 200) {
            NSLog(@"[JetIM] request navi error, http code is %ld", (long)statusCode);
            if (failure) {
                if (statusCode == 401) {
                    failure(JErrorCodeInternalTokenIllegal);
                } else {
                    failure(JErrorCodeInternalNaviFailure);
                }
            }
            return;
        }
        NSError *e = nil;
        NSDictionary *responseDic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&e];
        if (e) {
            NSLog(@"[JetIM] request navi json error, description is %@", e.localizedDescription);
            if (failure) {
                failure(JErrorCodeInternalNaviFailure);
            }
            return;
        }
        if (responseDic) {
            NSDictionary *dataDic = responseDic[jNaviData];
            if (dataDic) {
                NSString *userId = dataDic[jNaviUserId]?:@"";
                NSArray *servers = dataDic[jNaviServers];
                if (success) {
                    success(userId, servers);
                    return;
                }
            }
        }
        NSLog(@"[JetIM] request navi unknown error");
        if (failure) {
            failure(JErrorCodeInternalNaviFailure);
        }
    }];
    
    [task resume];
}

@end

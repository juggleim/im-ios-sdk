//
//  JUserInfoDB.m
//  JetIM
//
//  Created by Nathan on 2024/3/12.
//

#import "JUserInfoDB.h"

NSString *const jCreateUserTable = @"CREATE TABLE IF NOT EXISTS user ("
                                        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                                        "user_id VARCHAR (64),"
                                        "name VARCHAR (64),"
                                        "portrait TEXT,"
                                        "extension TEXT"
                                        ")";
NSString *const jCreateGroupTable = @"CREATE TABLE IF NOT EXISTS group_info ("
                                        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                                        "group_id VARCHAR (64),"
                                        "name VARCHAR (64),"
                                        "portrait TEXT,"
                                        "extension TEXT"
                                        ")";
NSString *const jCreateUserIndex = @"CREATE UNIQUE INDEX IF NOT EXISTS idx_user ON user(user_id)";
NSString *const jCreateGroupIndex = @"CREATE UNIQUE INDEX IF NOT EXISTS idx_group ON group_info(group_id)";
NSString *const jGetUserInfo = @"SELECT * FROM user WHERE user_id = ?";
NSString *const jGetGroupInfo = @"SELECT * FROM group_info WHERE group_id = ?";
NSString *const jInsertUserInfo = @"INSERT OR REPLACE INTO user (user_id, name, portrait, extension) VALUES (?, ?, ?, ?)";
NSString *const jInsertGroupInfo = @"INSERT OR REPLACE INTO group_info (group_id, name, portrait, extension) VALUES (?, ?, ?, ?)";
NSString *const jColUserId = @"user_id";
NSString *const jColGroupId = @"group_id";
NSString *const jColUserInfoName = @"name";
NSString *const jColUserInfoPortrait = @"portrait";
NSString *const jColUserInfoExtension = @"extension";

@interface JUserInfoDB ()
@property (nonatomic, strong) JDBHelper *dbHelper;
@end

@implementation JUserInfoDB

- (void)createTables {
    [self.dbHelper executeUpdate:jCreateUserTable withArgumentsInArray:nil];
    [self.dbHelper executeUpdate:jCreateGroupTable withArgumentsInArray:nil];
    [self.dbHelper executeUpdate:jCreateUserIndex withArgumentsInArray:nil];
    [self.dbHelper executeUpdate:jCreateGroupIndex withArgumentsInArray:nil];
}

- (instancetype)initWithDBHelper:(JDBHelper *)dbHelper {
    JUserInfoDB *db = [[JUserInfoDB alloc] init];
    db.dbHelper = dbHelper;
    return db;
}

- (JUserInfo *)getUserInfo:(NSString *)userId {
    if (userId.length == 0) {
        return nil;
    }
    __block JUserInfo *userInfo = nil;
    [self.dbHelper executeQuery:jGetUserInfo
           withArgumentsInArray:@[userId]
                     syncResult:^(JFMResultSet * _Nonnull resultSet) {
        if ([resultSet next]) {
            userInfo = [self userInfoWith:resultSet];
        }
    }];
    return userInfo;
}

- (JGroupInfo *)getGroupInfo:(NSString *)groupId {
    if (groupId.length == 0) {
        return nil;
    }
    __block JGroupInfo *groupInfo = nil;
    [self.dbHelper executeQuery:jGetGroupInfo
           withArgumentsInArray:@[groupId]
                     syncResult:^(JFMResultSet * _Nonnull resultSet) {
        if ([resultSet next]) {
            groupInfo = [self groupInfoWith:resultSet];
        }
    }];
    return groupInfo;
}

- (void)insertUserInfos:(NSArray <JUserInfo *> *)userInfos {
    [self.dbHelper executeTransaction:^(JFMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        [userInfos enumerateObjectsUsingBlock:^(JUserInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *userId = obj.userId?:@"";
            NSString *name = obj.userName?:@"";
            NSString *portrait = obj.portrait?:@"";
            NSString *extension = @"";
            [db executeUpdate:jInsertUserInfo withArgumentsInArray:@[userId, name, portrait, extension]];
        }];
    }];
}

- (void)insertGroupInfos:(NSArray <JGroupInfo *> *)groupInfos {
    [self.dbHelper executeTransaction:^(JFMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        [groupInfos enumerateObjectsUsingBlock:^(JGroupInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *groupId = obj.groupId?:@"";
            NSString *name = obj.groupName?:@"";
            NSString *portrait = obj.portrait?:@"";
            NSString *extension = @"";
            [db executeUpdate:jInsertGroupInfo withArgumentsInArray:@[groupId, name, portrait, extension]];
        }];
    }];
}

#pragma mark - internal
- (JUserInfo *)userInfoWith:(JFMResultSet *)rs {
    JUserInfo *userInfo = [[JUserInfo alloc] init];
    userInfo.userId = [rs stringForColumn:jColUserId];
    userInfo.userName = [rs stringForColumn:jColUserInfoName];
    userInfo.portrait = [rs stringForColumn:jColUserInfoPortrait];
    return userInfo;
}

- (JGroupInfo *)groupInfoWith:(JFMResultSet *)rs {
    JGroupInfo *groupInfo = [[JGroupInfo alloc] init];
    groupInfo.groupId = [rs stringForColumn:jColGroupId];
    groupInfo.groupName = [rs stringForColumn:jColUserInfoName];
    groupInfo.portrait = [rs stringForColumn:jColUserInfoPortrait];
    return groupInfo;
}

@end

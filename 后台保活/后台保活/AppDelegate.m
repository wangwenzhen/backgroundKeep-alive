//
//  AppDelegate.m
//  后台保活
//
//  Created by wondertek on 2018/7/10.
//  Copyright © 2018年 wondertek. All rights reserved.
//

#import "AppDelegate.h"
#import <UserNotifications/UserNotifications.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/NSNotification.h>
#define isActiveBackgroundLocation      0
/**
 后台无限保活 - ReadMe
        通过本地推送 添加应用角标来测试；
 
        1. 启用后台定位服务【
                            -》应用内定位（熊通知栏会提示 该应用正在使用定位服务）
                            -》始终定位 （后台默默处理，通知栏无状态描述）
                         】
        2. 启用后台音频播放【无声循环】
 */
@interface AppDelegate ()<CLLocationManagerDelegate>{
    CLLocationManager *_location;
}
@property (nonatomic) dispatch_source_t badgeTimer;
@property (nonatomic, strong) AVAudioPlayer *player;
@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self localNotification];
    
    if (isActiveBackgroundLocation) {
        [self localLocation];//启动定位服务
    } else {
        [self player];//配置后台无声音频
    }
    
    return YES;
}
/** 本地通知 */
- (void)localNotification{
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert) completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (!error) {
            NSLog(@"request authorization succeeded!");
        }
    }];
}


/** 本地定位 */
- (void)localLocation{
    UIAlertView *alert;
    //判断定位权限
    if([UIApplication sharedApplication].backgroundRefreshStatus == UIBackgroundRefreshStatusDenied){
        alert = [[UIAlertView alloc]initWithTitle:@"提示" message:@"应用没有不可以定位，需要在在设置/通用/后台应用刷新开启" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
    } else if ([UIApplication sharedApplication].backgroundRefreshStatus == UIBackgroundRefreshStatusRestricted)
    {
        alert = [[UIAlertView alloc]initWithTitle:@"提示" message:@"设备不可以定位" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
    } else{
        _location = [[CLLocationManager alloc]init];
        _location.desiredAccuracy = kCLLocationAccuracyBestForNavigation;//导航级别的精确度

        [_location requestAlwaysAuthorization];
        _location.allowsBackgroundLocationUpdates = YES; //允许后台刷新
        _location.pausesLocationUpdatesAutomatically = NO; //不允许自动暂停刷新
        _location.distanceFilter = kCLDistanceFilterNone;  //不需要移动都可以刷新
        [_location startUpdatingLocation];
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    if (isActiveBackgroundLocation) {
        _location.delegate = self;
        /** 启动后台服务 */
        [_location startUpdatingLocation];
    } else {
        [self.player play];
    }
    
    [self startLocalNotification];
    [self applyKeepalive];
}

/** 申请延期保活 */
- (void)applyKeepalive{
    UIApplication *application = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier bgTask;
    bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        //这里延迟的系统时间结束
        [application endBackgroundTask:bgTask];
        NSLog(@"%f",application.backgroundTimeRemaining);
    }];
}
/** 进行本地通知 【我们课可以在 此处 进行相应的后台任务】*/
- (void)startLocalNotification{
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    
    _badgeTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_badgeTimer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_badgeTimer, ^{
        [UIApplication sharedApplication].applicationIconBadgeNumber++;
    });
    dispatch_resume(_badgeTimer);
}

/** 苹果_用户位置更新后，会调用此函数 */
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    [_location stopUpdatingLocation];
    _location.delegate = nil;
    NSLog(@"success");
}

/** 苹果_定位失败后，会调用此函数 */
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    [_location stopUpdatingLocation];
    _location.delegate = nil;
    NSLog(@"error");
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    if (isActiveBackgroundLocation) {
        /** 进入前台 关闭定位服务，节省电源 */
        [_location stopUpdatingLocation];
        _location.delegate = nil;
    } else {
        [self.player pause];
    }
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - CLLocationManagerDelegat
- (AVAudioPlayer *)player{
    if (!_player){
        NSURL *url=[[NSBundle mainBundle]URLForResource:@"work5.mp3" withExtension:nil];
        _player = [[AVAudioPlayer alloc]initWithContentsOfURL:url error:nil];
        [_player prepareToPlay];
        //一直循环播放
        _player.numberOfLoops = -1;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:nil];
        
        [session setActive:YES error:nil];
    }
    return _player;
}
@end

// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


@import WireTransport;
@import WireUtilities;
@import WireTesting;
@import UIKit;

#import "MockTransportSession.h"
#import "MockTransportSession+internal.h"
#import "MockConnection.h"
#import "MockFlowManager.h"
#import "MockUser.h"


@interface TestPushChannelEvent : NSObject

@property (nonatomic, readonly) ZMTUpdateEventType type;
@property (nonatomic, readonly) id<ZMTransportData> payload;
@property (nonatomic, readonly) NSUUID *uuid;
@property (nonatomic, readonly) BOOL isTransient;

@end



@interface MockTransportSessionTests : ZMTBaseTest

@property (nonatomic) MockTransportSession *sut;
@property (nonatomic) ZMPersistentCookieStorage *cookieStorage;
/// Array of TestPushChannelEvent
@property (nonatomic) NSMutableArray *pushChannelReceivedEvents;
@property (nonatomic) NSUInteger pushChannelDidOpenCount;
@property (nonatomic) NSUInteger pushChannelDidCloseCount;

@end


@interface MockTransportSessionTests (Utility)

- (ZMTransportResponse *)responseForImageData:(NSData *)imageData contentDisposition:(NSDictionary *)contentDisposition path:(NSString *)path;
- (ZMTransportResponse *)responseForImageData:(NSData *)imageData metaData:(NSData *)metaData imageMediaType:(NSString *)imageMediaType path:(NSString *)path;

- (ZMTransportResponse *)responseForFileData:(NSData *)fileData path:(NSString *)path metadata:(NSData *)metadata contentType:(NSString *)contentType;

- (ZMTransportResponse *)responseForPayload:(id<ZMTransportData>)payload path:(NSString *)path method:(ZMTransportRequestMethod)method;
- (ZMTransportResponse *)responseForProtobufData:(NSData *)data path:(NSString *)path method:(ZMTransportRequestMethod)method;

- (void)checkThatTransportData:(id <ZMTransportData>)dict matchesUser:(MockUser *)user isConnected:(BOOL)isConnected failureRecorder:(ZMTFailureRecorder *)fr;
- (void)checkThatTransportData:(id <ZMTransportData>)dict matchesConnection:(MockConnection *)connection;
- (void)checkThatTransportData:(id <ZMTransportData>)dict matchesConversation:(MockConversation *)conversation;
- (ZMTransportRequestGenerator)createGeneratorForPayload:(id<ZMTransportData>)payload path:(NSString *)path method:(ZMTransportRequestMethod)method handler:(ZMCompletionHandler *)handler;
- (TestPushChannelEvent *)popEvent;
- (TestPushChannelEvent *)popEventMatchingWithBlock:(BOOL(^)(TestPushChannelEvent *event))block;
-(void)createAndOpenPushChannel;
- (void)createAndOpenPushChannelAndCreateSelfUser:(BOOL)shouldCreateSelfUser;


@end


@interface MockTransportSessionTests (PushChannel) <ZMPushChannelConsumer>
@end

